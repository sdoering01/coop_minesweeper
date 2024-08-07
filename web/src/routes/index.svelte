<script lang="ts">
    import { browser } from '$app/env';
    import { goto } from '$app/navigation';
    import { page } from '$app/stores';
    import { onDestroy } from 'svelte';
    import type { Channel } from 'phoenix';
    import MdBlock from 'svelte-icons/md/MdBlock.svelte';

    import { socket } from '$lib/socket';
    import GameList from '$components/GameList.svelte';
    import toasts, { ToastType } from '$lib/stores/toast-store'

    const presets = [
        { name: 'Easy', size: 14, mines: 20 },
        { name: 'Medium', size: 22, mines: 50 },
        { name: 'Hard', size: 30, mines: 120 }
    ];

    let channel: Channel;
    let connecting = true;
    let loading = true;
    let createError = '';
    let size = presets[0].size;
    let mines = presets[0].mines;
    let privateGame = false;

    if (browser) {
        channel = socket.channel('lobby');
        channel
            .join()
            .receive('ok', () => {
                loading = false;
                connecting = false;
            })
            .receive('error', () => {
                channel.leave()
                toasts.show('Could not connect to the server. Please try again later.', ToastType.ERROR)
            });
    }

    onDestroy(() => {
        if (browser) {
            channel.leave();
        }
    });

    const handleCreateGame = () => {
        loading = true;
        const visibility = privateGame ? 'private' : 'public';
        channel
            .push('create_game', { size, mines, visibility })
            .receive('ok', ({ game_id: gameId }) => {
                goto(`/g/${gameId}`);
            })
            .receive('error', ({ message }) => {
                createError = message;
                loading = false;
            });
    };
</script>

<svelte:head>
    <title>CoopMinesweeper</title>
    <meta property="og:title" content="CoopMinesweeper" />
    <meta
        property="og:description"
        content="CoopMinesweeper is the place where you can play Minesweeper together with your friends"
    />
    <!-- TODO: Change image -->
    <meta property="og:image" content={$page.url.origin + '/favicon.png'} />
    <meta property="og:type" content="website" />
    <meta property="og:url" content={$page.url.toString()} />
</svelte:head>

<div class="flex flex-col gap-8 px-4 max-w-[100rem] mx-auto min-h-screen xl:flex-row xl:px-16">
    <div
        class="flex-1 flex-grow-[2] grid place-items-center text-center xl:sticky xl:top-0 xl:max-h-screen"
    >
        <div class="py-16 xl:mb-32 drop-shadow-xl">
            <h1 class="text-3xl text-accent font-bold mb-8 xl:text-4xl">
                Welcome to CoopMinesweeper
            </h1>
            <h2 class="text-2xl text-accent font-semibold opacity-75">
                The place where you can play Minesweeper with your friends
            </h2>
        </div>
    </div>
    <div class="hidden divider divider-vertical py-24 xl:flex xl:sticky xl:top-0 xl:max-h-screen" />
    <div class="flex-1 flex-grow-[3] pb-4 xl:py-16">
        <form
            on:submit|preventDefault={handleCreateGame}
            class="card p-8 max-w-[24rem] mx-auto bg-base-200 shadow-xl"
        >
            <h2 class="text-2xl font-semibold text-center mb-2">Create a new Game</h2>

            {#if createError}
                <div class="alert alert-error">
                    <div class="flex-1">
                        <span class="icon mr-2"><MdBlock /></span>
                        <span>{createError}</span>
                    </div>
                </div>
            {/if}

            <label for="field-size" class="label"><span class="label-text">Size</span></label>
            <input
                id="field-size"
                type="number"
                class="input"
                autocomplete="off"
                bind:value={size}
            />
            <label for="field-mines" class="label"><span class="label-text">Mines</span></label>
            <input
                id="field-mines"
                type="number"
                class="input"
                autocomplete="off"
                bind:value={mines}
            />
            <p class="label"><span class="label-text">Preset</span></p>
            <div class="btn-group">
                {#each presets as preset}
                    <button
                        type="button"
                        on:click={() => {
                            size = preset.size;
                            mines = preset.mines;
                        }}
                        class="flex-1 btn btn-sm btn-outline no-animation"
                        class:btn-active={size === preset.size && mines === preset.mines}
                        >{preset.name}</button
                    >
                {/each}
            </div>
            <div class="form-control">
                <label class="cursor-pointer label">
                    <span class="label-text"
                        >Make game private
                        <span
                            data-tip="Only people with a special link can join the game"
                            class="tooltip underline -ml-1 p-1 before:w-40 before:content-[attr(data-tip)] before:bg-base-300 after:border-t-base-300"
                            >?</span
                        >
                    </span>
                    <input type="checkbox" class="toggle" bind:value={privateGame} />
                </label>
            </div>
            <button type="submit" disabled={connecting} class="btn btn-primary" class:loading
                >Create game</button
            >
        </form>

        <div class="divider w-60 mx-auto my-8">OR</div>

        <GameList />
    </div>
</div>

<style>
    input::-webkit-outer-spin-button,
    input::-webkit-inner-spin-button {
        display: none;
        margin: 0;
    }

    input[type='number'] {
        -moz-appearance: textfield;
    }
</style>
