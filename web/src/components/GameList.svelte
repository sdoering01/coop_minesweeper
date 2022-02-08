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

    import { backendUrl } from '$lib/config';

    let gameList: GameEntry[] = null;

    onMount(() => {
        fetchGames();
    });

    const fetchGames = async () => {
        // TODO: Handle errors when toasts are implemented
        const response = await fetch(`${backendUrl}/games`);
        if (response.ok) {
            const unparsedGameList = await response.json();
            gameList = unparsedGameList.map(({ id, size, mines, mines_left, player_count }) => ({
                id,
                size,
                mines,
                minesLeft: mines_left,
                playerCount: player_count
            }));
        }
    };
</script>

<div>
    Public games
    {#if gameList == null}
        Loading...
    {:else}
        <button on:click={fetchGames}>Refresh</button>
        {#if gameList.length === 0}
            <p>There are no games</p>
        {:else}
            <ul>
                {#each gameList as { id, size, mines, minesLeft, playerCount }}
                    <li>
                        <h4>Game {id}</h4>
                        <ul>
                            <li>Size: {size}</li>
                            <li>Mines: {mines}</li>
                            <li>Mines left: {minesLeft}</li>
                            <li>Player count: {playerCount}</li>
                        </ul>
                        <a href="/g/{id}">Join</a>
                    </li>
                {/each}
            </ul>
        {/if}
    {/if}
</div>
