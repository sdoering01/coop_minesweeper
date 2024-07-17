<script context="module" lang="ts">
    interface GameEntry {
        id: string;
        size: number;
        mines: number;
        minesLeft: number;
        playerCount: number;
    }
</script>

<script lang="ts">
    import { onMount } from 'svelte';
    import MineIcon from '$components/MineIcon.svelte';
    import MdPerson from 'svelte-icons/md/MdPerson.svelte';
    import GoArrowBoth from 'svelte-icons/go/GoArrowBoth.svelte';
    import MdRefresh from 'svelte-icons/md/MdRefresh.svelte';
    import MdBlock from 'svelte-icons/md/MdBlock.svelte';

    import { backendUrl } from '$lib/config';

    let gameList: GameEntry[] = null;
    let loading = true;
    let loadError = '';

    onMount(() => {
        fetchGames();
    });

    const fetchGames = async () => {
        loading = true;
        let response: Response;
        try {
            response = await fetch(`${backendUrl}/games`);
        } catch (ex) {
            loadError = 'Could not load games. Maybe the server is down ...';
            loading = false;
            return;
        }

        if (response?.ok) {
            const unparsedGameList = await response.json();
            gameList = unparsedGameList.map(({ id, size, mines, mines_left, player_count }) => ({
                id,
                size,
                mines,
                minesLeft: mines_left,
                playerCount: player_count
            }));
            loadError = '';
        } else {
            loadError = 'An unexpected error occurred';
        }
        loading = false;
    };
</script>

<div class="max-w-[50rem] mx-auto flex flex-col items-center">
    <header class="flex items-center mb-6">
        <h2 class="text-2xl font-semibold">Join a public game</h2>
        <button
            on:click={fetchGames}
            class="btn btn-sm btn-square btn-ghost mt-1 ml-1"
            class:loading
        >
            {#if !loading}
                <span class="icon m-0"><MdRefresh /></span>
            {/if}
        </button>
    </header>
    {#if loadError}
        <div class="alert alert-error">
            {loadError}
        </div>
    {:else if gameList?.length === 0}
        <div class="alert alert-info">
            There are no games
        </div>
    {:else if gameList?.length > 0}
        <div class="flex flex-wrap gap-4 justify-center">
            {#each gameList as { id, size, mines, playerCount }}
                <div class="card bg-base-200 shadow-md w-60 px-6 py-4">
                    <h4 class="text-xl text-center">Game {id}</h4>
                    <div class="mt-2 mb-4 flex justify-between px-4">
                        <div class="game-stat">
                            <span title="Players" class="icon"><MdPerson /></span>{playerCount}
                        </div>
                        <div class="game-stat">
                            <span title="Size" class="icon"><GoArrowBoth /></span>{size}
                        </div>
                        <div class="game-stat">
                            <span title="Mines" class="icon"><MineIcon /></span>
                            {mines}
                        </div>
                    </div>
                    <a href="/g/{id}" class="btn btn-sm btn-primary">Enter</a>
                </div>
            {/each}
        </div>
    {/if}
</div>

<style lang="postcss">
    .game-stat {
        @apply flex items-center;
    }

    .game-stat > .icon {
        @apply text-slate-500;
    }
</style>
