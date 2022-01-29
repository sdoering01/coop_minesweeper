<script lang="ts">
    import { browser } from '$app/env';
    import { goto } from '$app/navigation';
    import { onDestroy } from 'svelte';
    import type { Channel } from 'phoenix';

    import { socket } from '$lib/socket';

    let channel: Channel;
    let loading = true;

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
            .push('create_game', {})
            .receive('ok', ({ game_id: gameId }) => {
                console.log('Created game with id', gameId);
                goto(`/g/${gameId}`);
            })
            .receive('error', () => {
                console.log('Could not create game');
                loading = false;
            });
    };
</script>

<h1>CoopMinesweeper</h1>
<p>Play Minesweeper with your friends</p>

<button on:click={handleCreateGame} disabled={loading}>Create game</button>
