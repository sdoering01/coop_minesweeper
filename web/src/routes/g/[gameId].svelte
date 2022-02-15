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
    import { fade, fly } from 'svelte/transition';
    import { page } from '$app/stores';
    import MdArrowBack from 'svelte-icons/md/MdArrowBack.svelte';
    import MdPerson from 'svelte-icons/md/MdPerson.svelte';
    import MdRemoveRedEye from 'svelte-icons/md/MdRemoveRedEye.svelte';
    import MdShare from 'svelte-icons/md/MdShare.svelte';
    import MdCheck from 'svelte-icons/md/MdCheck.svelte';

    import { socket } from '$lib/socket';
    import type { Changes } from '$lib/Field';
    import FieldCanvas from '$components/FieldCanvas.svelte';
    import toasts, { ToastType } from '$lib/stores/toast-store';

    export let gameId: string;
    export let fieldInfo: FieldInfo;

    let channel: Channel;
    let presence: Presence;
    let field: Field;
    let name = browser ? localStorage.getItem(NAME_STORAGE_KEY) || '' : '';
    let userList: User[] = [];
    let spectators = 0;
    let joined = false;
    let joinDialogOpen = true;
    let shareEffectActive = false;
    let shareEffectTimeout: NodeJS.Timeout;

    let paintChanges: (changes: Changes) => void;
    let repaint: () => void;

    if (browser && fieldInfo) {
        onMount(() => {
            channel = socket.channel(`game:${gameId}`);
            presence = new Presence(channel);
            channel
                .join()
                .receive('ok', (payload) => {
                    field = new Field(payload.field);
                })
                .receive('error', (payload) => {
                    let error = 'An unexpected error occured';
                    if (payload.reason === 'does_not_exist') {
                        error = 'A game with that id does not exist';
                    }
                    toasts.show(error, ToastType.ERROR)
                    channel.leave();
                });

            channel.on('field:update', (payload) => {
                field = new Field(payload.field);
            });

            channel.on('field:changes', (payload) => {
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
                const allUsers = presence.list((userId, { metas: [{ name, joined }] }) => {
                    return { userId, name, joined };
                });
                userList = allUsers
                    .filter(({ joined }) => joined)
                    .sort((u1, u2) => {
                        if (u1.name < u2.name) return -1;
                        if (u1.name > u2.name) return 1;
                        return 0;
                    });
                spectators = allUsers.length - userList.length;
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
            joinDialogOpen = false;
        });
    };

    const handlePlayAgain = () => {
        if (field.state !== FieldState.RUNNING) {
            channel.push('game:play_again', {}).receive('error', ({ reason }) => {
                toasts.show(`Could not play again (${reason})`, ToastType.ERROR);
            });
        }
    };

    const handleShare = async () => {
        try {
            await navigator.clipboard.writeText(window.location.href);
            shareEffectActive = true;
            clearTimeout(shareEffectTimeout);
            shareEffectTimeout = setTimeout(() => {
                shareEffectActive = false;
            }, 2000);
        } catch (ex) {
            toasts.show('Could not copy link', ToastType.ERROR);
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

<div class="site-container max-w-[100rem] mx-auto p-2 gap-2 md:h-screen md:p-4">
    <header class="navbar bg-neutral text-neutral-content rounded-box">
        <div class="navbar-start px-2">
            <a href="/" class="btn btn-ghost btn-sm px-2"
                ><span class="icon"><MdArrowBack /></span>Back to lobby</a
            >
        </div>
        <div class="navbar-center px-2 hidden sm:flex">
            <h2 class="text-xl font-semibold text-accent">CoopMinesweeper</h2>
        </div>
        <div class="navbar-end">
            <!-- TODO: Settings will go here -->
        </div>
    </header>
    {#if !fieldInfo}
        <div class="mt-2 col-span-full grid place-items-center">
            <div class="alert alert-error text-xl">This game does not exist</div>
        </div>
    {:else}
        <div
            class="field-container bg-neutral card p-4 relative h-full w-full max-h-full max-w-full grid place-items-center"
            on:contextmenu|preventDefault
        >
            {#if field}
                {#if joinDialogOpen}
                    <div
                        class="absolute inset-0 grid place-items-center backdrop-blur-sm bg-black bg-opacity-50"
                        transition:fade|local={{ duration: 300 }}
                    >
                        <div
                            class="card bg-neutral shadow-2xl bg-opacity-80 px-6 py-4 w-72 sm:w-auto"
                            transition:fly|local={{ y: 15, duration: 300 }}
                        >
                            <form on:submit|preventDefault={handleJoin}>
                                <p class="mb-4 text-center sm:text-xl">
                                    Enter your name to participate
                                </p>
                                <div class="flex space-x-2">
                                    <input
                                        type="text"
                                        placeholder="Anonymous"
                                        bind:value={name}
                                        use:autoFocus
                                        spellcheck="false"
                                        class="input input-primary min-w-0"
                                    />
                                    <button type="submit" class="btn btn-primary">Join</button>
                                </div>
                            </form>
                            <div class="divider mx-12">OR</div>
                            <button
                                on:click={() => (joinDialogOpen = false)}
                                class="btn btn-secondary">Spectate</button
                            >
                        </div>
                    </div>
                {/if}
                <FieldCanvas {field} {channel} {joined} bind:paintChanges bind:repaint />
            {/if}
        </div>
        <div class="game-info bg-neutral card p-4">
            <div class="flex justify-between items-center mb-1">
                <h3 class="text-xl">Game {gameId}</h3>
                <button
                    on:click={handleShare}
                    title="Share game link"
                    class="relative btn btn-sm btn-square"
                    class:btn-ghost={!shareEffectActive}
                    class:btn-success={shareEffectActive}
                >
                    {#if shareEffectActive}
                        <span
                            class="text-base-200 absolute w-max right-9 bg-success p-1 rounded-md before:absolute before:-right-3 before:top-[3px] before:border-8 before:border-transparent before:border-l-success"
                        >
                            Link copied
                        </span>
                    {/if}
                    <span class="w-full h-full overflow-hidden relative">
                        {#if shareEffectActive}
                            <span
                                class="absolute inset-1"
                                transition:fly|local={{ duration: 300, y: 20 }}><MdCheck /></span
                            >
                        {:else}
                            <span
                                class="absolute inset-1"
                                transition:fly|local={{ duration: 300, y: -20 }}><MdShare /></span
                            >
                        {/if}
                    </span>
                </button>
            </div>
            {#if field}
                <p>Size: {field.size} &bull; Mines: {field.mines}</p>
                <p>Mines left: {field.minesLeft}</p>
                <p>
                    {#if field.state === FieldState.RUNNING}
                        Game running
                    {:else}
                        Game {field.state === FieldState.WON ? 'won' : 'lost'} by {field.recentPlayer}
                    {/if}
                </p>
                {#if joined && field.state !== FieldState.RUNNING}
                    <button on:click={handlePlayAgain} class="btn btn-primary btn-sm mt-2"
                        >Play again</button
                    >
                {/if}
                {#if !joined && !joinDialogOpen}
                    <div class="divider my-1" />
                    <div class="flex flex-col">
                        <p class="mb-2 flex items-center">
                            <span class="icon inline-block mr-2"><MdRemoveRedEye /></span>You are
                            spectating
                        </p>
                        <button
                            on:click={() => (joinDialogOpen = true)}
                            class="btn btn-primary btn-sm">Join</button
                        >
                    </div>
                {/if}
            {/if}
        </div>
        <div class="player-info bg-neutral card p-4">
            {#if field}
                <div class="flex justify-between align-center mb-4">
                    <div class="flex items-center">
                        <span class="icon"><MdPerson /></span>Players ({userList.length})
                    </div>
                    <div class="flex items-center">
                        <span class="icon"><MdRemoveRedEye /></span>{spectators}
                    </div>
                </div>
                <ul class="overflow-y-auto space-y-1">
                    {#each userList as { userId, name } (userId)}
                        <li transition:fade|local class="truncate max-w-full">{name}</li>
                    {/each}
                </ul>
            {/if}
        </div>
    {/if}
</div>

<style lang="postcss">
    .site-container {
        display: grid;
        grid-template-areas:
            'header'
            'game-info'
            'field'
            'player-info';
        grid-template-rows: auto auto fit-content(80vh) fit-content(50vh);
    }

    .site-container > header {
        grid-area: header;
    }

    .field-container {
        grid-area: field;
    }

    .game-info {
        grid-area: game-info;
    }

    .player-info {
        grid-area: player-info;
    }

    @media screen(md) {
        .site-container {
            grid-template-areas:
                'header header'
                'field game-info'
                'field player-info';
            grid-template-columns: auto 250px;
            grid-template-rows: auto auto minmax(0, 1fr);
        }
    }
</style>
