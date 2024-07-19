<script context="module" lang="ts">
    import type { Load } from '@sveltejs/kit';

    import { Field, FieldState } from '$lib/Field';
    import { backendUrl } from '$lib/config';

    const NAME_STORAGE_KEY = 'coop_minesweeper_name';
    const HIDE_HELP_STORAGE_KEY = 'coop_minesweeper_hide_help';

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
        isBot: boolean | undefined;
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
    import MdHelp from 'svelte-icons/md/MdHelp.svelte';

    import { socket } from '$lib/socket';
    import type { Changes } from '$lib/Field';
    import FieldCanvas from '$components/FieldCanvas.svelte';
    import toasts, { ToastType } from '$lib/stores/toast-store';
    import { hideBodyOverflow } from '$lib/hooks/hide-body-overflow';

    export let gameId: string;
    export let fieldInfo: FieldInfo;

    let channel: Channel;
    let presence: Presence;
    let field: Field;
    let name = (browser && localStorage.getItem(NAME_STORAGE_KEY)) || '';
    let userList: User[] = [];
    let realPlayers = 0;
    let bots = 0;
    let spectators = 0;
    let joined = false;
    let joinDialogOpen = true;
    let dontShowHelpAgain =
        browser && localStorage.getItem(HIDE_HELP_STORAGE_KEY)
            ? JSON.parse(localStorage.getItem(HIDE_HELP_STORAGE_KEY))
            : true;
    // Show help when the user visits for the first time or explictly wants to
    // see the help
    let helpModalOpen =
        (browser && !localStorage.getItem(HIDE_HELP_STORAGE_KEY)) || !dontShowHelpAgain;
    let shareEffectActive = false;
    let shareEffectTimeout: NodeJS.Timeout;
    let nameInput: HTMLInputElement;

    let gameTimerInterval: NodeJS.Timer;
    let gameTimerSeconds: number = 0;

    let paintChanges: (changes: Changes) => void;
    let repaint: () => void;

    $: if (nameInput && !helpModalOpen) {
        nameInput.focus();
    }

    if (browser && fieldInfo) {
        onMount(() => {
            channel = socket.channel(`game:${gameId}`);
            presence = new Presence(channel);
            channel
                .join()
                .receive('ok', (payload) => {
                    field = new Field(payload.field);

                    if (field.started_at != null && field.state === FieldState.RUNNING) {
                        startGameTimer(field.gameSeconds());
                    } else {
                        gameTimerSeconds = field.gameSeconds();
                    }
                })
                .receive('error', (payload) => {
                    let error = 'An unexpected error occured';
                    if (payload.reason === 'does_not_exist') {
                        error = 'A game with that id does not exist';
                        // Set fieldInfo to null so when the player opens a
                        // cached version of a game that doesn't exist anymore
                        // it correctly shows the error message.
                        fieldInfo = null;
                    }
                    toasts.show(error, ToastType.ERROR);
                    channel.leave();
                });

            channel.on('field:changes', (payload) => {
                const old_started_at = field.started_at;

                field.handleChanges(payload.field, payload.changes);

                if (old_started_at == null && field.started_at != null && field.state === FieldState.RUNNING) {
                    startGameTimer(field.gameSeconds());
                } else if (field.state === FieldState.WON || field.state === FieldState.LOST) {
                    cancelGameTimer();
                    gameTimerSeconds = field.gameSeconds();
                }

                field = field;
                paintChanges?.(payload.changes);
            });

            channel.on('game:play_again', (payload) => {
                gameTimerSeconds = 0;

                field.playAgain(payload.field);
                field = field;
                repaint?.();
            });

            presence.onSync(() => {
                const allUsers = presence.list((userId, { metas: [{ name, joined, "bot?": isBot }] }) => {
                    return { userId, name, joined, isBot };
                });
                userList = allUsers
                    .filter(({ joined }) => joined)
                    .sort((u1, u2) => {
                        if (u1.name < u2.name) return -1;
                        if (u1.name > u2.name) return 1;
                        return 0;
                    });

                realPlayers = 0;
                bots = 0;
                for (const user of userList) {
                    if (user.isBot) {
                        bots += 1;
                    } else {
                        realPlayers += 1;
                    }
                }

                spectators = allUsers.length - userList.length;
            });
        });

        onDestroy(() => {
            channel?.leave();
            cancelGameTimer();
        });
    }

    const handleJoin = () => {
        localStorage.setItem(NAME_STORAGE_KEY, name);
        channel.push('game:join', { name }).receive('ok', () => {
            joined = true;
            joinDialogOpen = false;
        });
    };

    const handleAddBot = () => {
        channel.push('bot:add', {});
    }

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

    const handleHelpDialogClose = () => {
        localStorage.setItem(HIDE_HELP_STORAGE_KEY, JSON.stringify(dontShowHelpAgain));
        helpModalOpen = false;
    };

    const startGameTimer = (initialSeconds: number) => {
        cancelGameTimer();

        gameTimerSeconds = initialSeconds;

        gameTimerInterval = setInterval(() => {
            gameTimerSeconds += 1;
        }, 1000);
    };

    const cancelGameTimer = () => {
        clearInterval(gameTimerInterval);
    };
</script>

<svelte:head>
    {#if fieldInfo}
        <title>CoopMinesweeper &bull; Game {gameId}</title>
        <meta property="og:title" content="CoopMinesweeper &bull; Game {gameId}" />
        <meta
            property="og:description"
            content="CoopMinesweeper &bull; Size: {fieldInfo.size} &bull; Mines: {fieldInfo.mines}"
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

{#if helpModalOpen && fieldInfo}
    <div
        use:hideBodyOverflow
        class="fixed inset-0 grid place-items-center bg-neutral-focus bg-opacity-60 z-50 xs:p-4"
    >
        <div
            class="space-y-2 p-4 bg-base-100 w-full h-full max-h-full overflow-y-auto xs:p-6 xs:rounded-box xs:max-w-lg xs:h-auto"
        >
            <h3 class="text-xl font-semibold">Welcome to CoopMinesweeper</h3>
            <p>
                This game is a remake of the classic game Minesweeper. It consists of a grid with
                tiles that can be either a mine or no mine.
            </p>
            <p>
                The goal is to reveal all tiles that are no mines. You lose, when you reveal a mine.
            </p>
            <p>
                When you reveal a tile which is no mine, it shows how many mines are in the eight
                tiles around it.
            </p>
            <p>
                If you think that know where a mine is, you can mark that tile to not accidentally
                reveal the mine later and lose.
            </p>
            <p>
                Additionally you can play this game with your friends. Just click the share symbol
                and send them the link!
            </p>
            <h3 class="text-xl font-semibold pt-2">Controls</h3>
            <p>
                You can <b>reveal a tile</b> by left clicking (computer) or tapping (mobile) it.
                <br />
                You can <b>mark a tile</b> as a mine or remove the mark by right clicking (computer)
                or long tapping (mobile) it.
                <br />
                When playing from a computer you can navigate a large field by dragging while holding
                down the middle mouse button.
            </p>
            <div class="divider" />
            <div>
                <label class="cursor-pointer label p-0 mb-4">
                    <span class="label-text">Don't show this again</span>
                    <input type="checkbox" bind:checked={dontShowHelpAgain} class="checkbox" />
                </label>
                <button on:click={handleHelpDialogClose} class="btn btn-primary btn-block"
                    >Close</button
                >
            </div>
        </div>
    </div>
{/if}

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
        <div class="navbar-end px-2">
            <!-- TODO: Settings will go here -->
            {#if fieldInfo}
                <button
                    on:click={() => (helpModalOpen = true)}
                    title="Help"
                    class="btn btn-sm btn-square btn-ghost"
                >
                    <span class="icon m-0"><MdHelp /></span>
                </button>
            {/if}
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
                        class="absolute inset-0 grid place-items-center backdrop-blur-sm bg-black bg-opacity-50 p-4"
                        transition:fade|local={{ duration: 300 }}
                    >
                        <div
                            class="card bg-neutral shadow-2xl bg-opacity-80 px-6 py-4 max-w-full max-h-full sm:max-w-md"
                            transition:fly|local={{ y: 15, duration: 300 }}
                        >
                            <form on:submit|preventDefault={handleJoin}>
                                <p class="mb-4 text-center text-xl">
                                    Enter your name to participate
                                </p>
                                <div class="flex space-x-2">
                                    <input
                                        type="text"
                                        placeholder="Anonymous"
                                        bind:value={name}
                                        bind:this={nameInput}
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
                    Time: {gameTimerSeconds} {gameTimerSeconds === 1 ? "second" : "seconds"}
                </p>
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
                        <span class="icon"><MdPerson /></span>Players ({realPlayers} + {bots})
                    </div>
                    <div class="flex items-center">
                        <span class="icon"><MdRemoveRedEye /></span>{spectators}
                    </div>
                </div>
                <div class="overflow-y-auto space-y-2">
                    <ul class="space-y-1">
                        {#each userList as { userId, name, isBot } (userId)}
                            <li transition:fade|local class="truncate max-w-full">{#if isBot}<i>Bot</i>{/if} {name}</li>
                        {/each}
                    </ul>
                    <button class="btn btn-primary btn-sm w-full" on:click={handleAddBot}>Add Bot</button>
                </div>
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
