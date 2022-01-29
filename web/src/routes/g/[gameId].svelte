<script context="module" lang="ts">
    export const load = ({ params }) => {
        return {
            props: {
                gameId: params.gameId
            }
        };
    };
</script>

<script lang="ts">
    import { browser } from '$app/env';
    import type { Channel } from 'phoenix';
    import { onDestroy } from 'svelte';

    import { socket } from '$lib/socket';
    import { Field, FieldState, TileState } from '$lib/Field';
    import Tile from '$components/Tile.svelte';

    export let gameId: string;

    let channel: Channel;
    let joinError = '';
    let field: Field;

    if (browser) {
        channel = socket.channel(`game:${gameId}`);
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
                    channel.leave();
                }
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
        });

        channel.on('game:play_again', (payload) => {
            field.playAgain(payload.field);
            field = field;
        });

        onDestroy(() => {
            channel.leave();
        });
    }

    const handleTileReveal = (row: number, col: number) => {
        if (field.state === FieldState.RUNNING) {
            console.log(`Reveal: row ${row}, col ${col}`);
            if (field.tiles[row][col].state === TileState.HIDDEN) {
                console.log('Pushing reveal to channel');
                channel.push('tile:reveal', { row, col }).receive('error', ({ reason }) => {
                    console.log(`Could not reveal tile in row ${row} and col ${col}: ${reason}`);
                });
            }
        }
    };

    const handleTileToggle = (row: number, col: number) => {
        if (field.state === FieldState.RUNNING) {
            console.log(`Toggle: row ${row}, col ${col}`);
            const state = field.tiles[row][col].state;
            if (state === TileState.HIDDEN || state === TileState.MARK) {
                console.log('Pushing toggle to channel');
                channel.push('tile:toggle', { row, col }).receive('error', ({ reason }) => {
                    console.log(`Could not toggle tile in row ${row} and col ${col}: ${reason}`);
                });
            }
        }
    };

    const handlePlayAgain = () => {
        if (field.state !== FieldState.RUNNING) {
            channel.push('game:play_again', {}).receive('error', ({ reason }) => {
                console.log(`Could not play again: ${reason}`);
            });
        }
    };
</script>

<a href="/">&larr; Back to lobby</a>
<h2>Game {gameId}</h2>
{#if joinError}
    <p>{joinError}</p>
{/if}
{#if field}
    <p>Mines left: {field.minesLeft}</p>
    <p>
        {#if field.state === FieldState.RUNNING}
            Game running
        {:else}
            Game {field.state === FieldState.WON ? 'won' : 'lost'}
            <button on:click={handlePlayAgain}>Play again</button>
        {/if}
    </p>
    <div class="field" class:running={field.state === FieldState.RUNNING} style:--size={field.size}>
        {#each field.tiles as row, rowIdx}
            {#each row as { state, minesClose }, colIdx}
                <Tile
                    on:click={() => handleTileReveal(rowIdx, colIdx)}
                    on:contextmenu={() => handleTileToggle(rowIdx, colIdx)}
                    {rowIdx}
                    {colIdx}
                    {state}
                    {minesClose}
                />
            {/each}
        {/each}
    </div>
{/if}

<style>
    .field {
        display: grid;
        grid-template-columns: repeat(var(--size), 40px);
        grid-template-rows: repeat(var(--size), 40px);
    }

    :global(.running > .tile.hidden) {
        cursor: pointer !important;
    }

    :global(.running > .tile.hidden:hover),
    :global(.running > .tile.mark:hover) {
        background-color: #ddd !important;
    }
</style>
