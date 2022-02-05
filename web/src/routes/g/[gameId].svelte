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
    import { onDestroy, onMount } from 'svelte';

    import { socket } from '$lib/socket';
    import { Field, FieldState, Changes } from '$lib/Field';
    import FieldCanvas from '$components/FieldCanvas.svelte';

    export let gameId: string;

    let channel: Channel;
    let joinError = '';
    let field: Field;

    let paintChanges: (changes: Changes) => void;
    let repaint: () => void;

    if (browser) {
        onMount(() => {
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
                if (paintChanges) {
                    paintChanges(payload.changes);
                }
            });

            channel.on('game:play_again', (payload) => {
                field.playAgain(payload.field);
                field = field;
                if (repaint) {
                    repaint();
                }
            });
        });

        onDestroy(() => {
            channel.leave();
        });
    }

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
{/if}
<!-- TODO: Make width and height dynamic -->
{#if field}
    <FieldCanvas {field} {channel} bind:paintChanges bind:repaint />
{/if}
