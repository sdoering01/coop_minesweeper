<script lang="ts">
    import { browser } from '$app/env';
    import { goto } from '$app/navigation';
    import { onDestroy } from 'svelte';
    import type { Channel } from 'phoenix';

    import { socket } from '$lib/socket';

    let channel: Channel;
    let loading = true;
    let createError = '';
    let size = 14;
    let mines = 20

    if (browser) {
        channel = socket.channel('lobby');
        channel
            .join()
            .receive('ok', () => {
                console.log('Joined lobby');
                loading = false;
            })
            .receive('error', () => console.log('Could not join lobby'));

        channel.onClose(() => {
            console.log('Left lobby');
        });
    }

    onDestroy(() => {
        if (browser) {
            channel.leave();
        }
    });

    const handleCreateGame = () => {
        loading = true;
        channel
            .push('create_game', {size, mines})
            .receive('ok', ({ game_id: gameId }) => {
                console.log('Created game with id', gameId);
                goto(`/g/${gameId}`);
            })
            .receive('error', ({reason, message}) => {
                console.log('Could not create game:', reason, message);
                createError = message;
                loading = false;
            });
    };
</script>

<h1>CoopMinesweeper</h1>
<p>Play Minesweeper with your friends</p>

{#if createError}
    <p>{createError}</p>
{/if}

<form on:submit|preventDefault={handleCreateGame} class="game-configuration">
    <label for="field-size">Size:</label>
    <input id="field-size" type="number" bind:value={size} />
    <label for="field-mines">Mines:</label>
    <input id="field-mines" type="number" bind:value={mines} />
    <button type="submit" disabled={loading}>Create game</button>
</form>

<style>
.game-configuration {
    display: grid;
    grid-template-columns: 50px 50px;
}

.game-configuration > button {
    grid-column: 1 / 3;
}
</style>
