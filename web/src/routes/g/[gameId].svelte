<script context="module" lang="ts">
    import type { Load } from '@sveltejs/kit';

    import { Field, FieldState } from '$lib/Field';
    import { backendUrl } from '$lib/config';
    import { autoFocus } from '$lib/hooks/auto-focus';

    const NAME_STORAGE_KEY = 'coop_minesweeper_name';

    interface FieldInfo {
        size: number;
        mines: number;
        minesLeft: number;
        state: string;
    }

    interface User {
        userId: string;
        name: string;
        joined: boolean;
    }

    export const load: Load = async ({ fetch, params: { gameId } }) => {
        let fieldInfo: FieldInfo = null;

        const response = await fetch(`${backendUrl}/games/${gameId}/info`);
        if (response.ok) {
            const json = await response.json();
            fieldInfo = {
                size: json.size,
                mines: json.mines,
                minesLeft: json.mines_left,
                state: json.state
            };
        }

        return {
            props: {
                gameId,
                fieldInfo
            }
        };
    };
</script>

<script lang="ts">
    import { browser } from '$app/env';
    import { type Channel, Presence } from 'phoenix';
    import { onDestroy, onMount } from 'svelte';
    import { fade } from 'svelte/transition';
    import { page } from '$app/stores';

    import { socket } from '$lib/socket';
    import type { Changes } from '$lib/Field';
    import FieldCanvas from '$components/FieldCanvas.svelte';

    export let gameId: string;
    export let fieldInfo: FieldInfo;

    let channel: Channel;
    let presence: Presence;
    let joinError = '';
    let field: Field;
    let name = browser ? localStorage.getItem(NAME_STORAGE_KEY) || '' : '';
    let userList: User[] = [];
    let spectators = 0;
    let joined = false;

    let paintChanges: (changes: Changes) => void;
    let repaint: () => void;

    if (browser) {
        onMount(() => {
            channel = socket.channel(`game:${gameId}`);
            presence = new Presence(channel);
            channel
                .join()
                .receive('ok', (payload) => {
                    console.log('Joined game with id', gameId);
                    console.log('join', payload.field);
                    field = new Field(payload.field);
                })
                .receive('error', (payload) => {
                    console.log('Could not join game with id', gameId);
                    if (payload.reason === 'does_not_exist') {
                        joinError = 'A game with that id does not exist';
                    } else {
                        joinError = 'An unexpected error occured';
                    }
                    channel.leave();
                });

            channel.onClose(() => console.log('Left game with id', gameId));

            channel.on('field:update', (payload) => {
                console.log('field:update', payload.field);
                field = new Field(payload.field);
            });

            channel.on('field:changes', (payload) => {
                console.log('field:changes', payload.field, payload.changes);
                field.handleChanges(payload.field, payload.changes);
                field = field;
                paintChanges?.(payload.changes);
            });

            channel.on('game:play_again', (payload) => {
                field.playAgain(payload.field);
                field = field;
                repaint?.();
            });

            presence.onSync(() => {
                const allUsers = presence.list((user_id, { metas: [{ name, joined }] }) => {
                    return { userId: user_id, name, joined };
                });
                userList = allUsers
                    .filter(({ joined }) => joined)
                    .sort((u1, u2) => {
                        if (u1.name < u2.name) return -1;
                        if (u1.name > u2.name) return 1;
                        return 0;
                    });
                spectators = allUsers.length - userList.length;
                console.log('presence.onSync', allUsers);
            });
        });

        onDestroy(() => {
            channel?.leave();
        });
    }

    const handleJoin = () => {
        localStorage.setItem(NAME_STORAGE_KEY, name);
        channel.push('game:join', { name }).receive('ok', () => {
            joined = true;
        });
    };

    const handlePlayAgain = () => {
        if (field.state !== FieldState.RUNNING) {
            channel.push('game:play_again', {}).receive('error', ({ reason }) => {
                console.log(`Could not play again: ${reason}`);
            });
        }
    };
</script>

<svelte:head>
    {#if fieldInfo}
        <title>CoopMinesweeper &bull; Game {gameId}</title>
        <meta property="og:title" content="CoopMinesweeper &bull; Game {gameId}" />
        <meta
            property="og:description"
            content="CoopMinesweeper &bull; Game {fieldInfo.state} &bull; Size: {fieldInfo.size} &bull; Mines: {fieldInfo.mines} &bull; Mines left: {fieldInfo.minesLeft}"
        />
    {:else}
        <title>CoopMinesweeper &bull; Game not found</title>
        <meta property="og:title" content="CoopMinesweeper &bull; Game not found" />
        <meta
            property="og:description"
            content="CoopMinesweeper &bull; This game does not exists"
        />
    {/if}
    <!-- TODO: Change image -->
    <meta property="og:image" content={$page.url.origin + '/favicon.png'} />
    <meta property="og:type" content="website" />
    <meta property="og:url" content={$page.url.toString()} />
</svelte:head>

<a href="/">&larr; Back to lobby</a>
<h2>Game {gameId}</h2>
{#if joinError}
    <p>{joinError}</p>
{/if}
<!-- TODO: Make width and height dynamic -->
{#if field}
    <p>Size: {field.size} &bull; Mines: {field.mines}</p>
    <p>Mines left: {field.minesLeft}</p>
    <p>
        {#if field.state === FieldState.RUNNING}
            Game running
        {:else}
            Game {field.state === FieldState.WON ? 'won' : 'lost'} by {field.recentPlayer}
            {#if joined}
                <button on:click={handlePlayAgain}>Play again</button>
            {/if}
        {/if}
    </p>
    <div class="field-wrapper">
        {#if !joined}
            <div class="join-overlay">
                <form on:submit|preventDefault={handleJoin}>
                    <p>Enter your name to participate</p>
                    <input type="text" placeholder="Anonymous" bind:value={name} use:autoFocus />
                    <button type="submit">Join</button>
                </form>
            </div>
        {/if}
        <FieldCanvas {field} {channel} bind:paintChanges bind:repaint />
    </div>
    <h3>Players ({spectators} spectator{spectators !== 1 ? 's' : ''})</h3>
    <ul>
        {#each userList as { userId, name } (userId)}
            <li transition:fade|local>{name}</li>
        {/each}
    </ul>
{/if}

<style>
    .field-wrapper {
        position: relative;
    }

    .join-overlay {
        position: absolute;
        top: 0;
        right: 0;
        bottom: 0;
        left: 0;
        background-color: rgba(0, 0, 0, 0.2);
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .join-overlay > form {
        padding: 32px;
        border-radius: 8px;
        background-color: rgba(0, 0, 0, 0.2);
        backdrop-filter: blur(4px);
    }
</style>
