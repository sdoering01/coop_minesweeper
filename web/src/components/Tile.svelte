<script lang="ts">
import { TileState } from '$lib/Field';

export let state: TileState;
export let minesClose: number;
export let rowIdx: number;
export let colIdx: number;

let extraClasses = '';

$: {
    extraClasses = ((rowIdx % 2) + colIdx) % 2 === 0 ? 'even' : 'odd';
    if (state === TileState.HIDDEN) {
        extraClasses += ' hidden';
    } else if (state === TileState.REVEALED) {
        extraClasses += ' revealed';
    } else if (state === TileState.MARK) {
        extraClasses += ' mark';
    } else if (state === TileState.MINE) {
        extraClasses += ' mine';
    } else if (state === TileState.FALSE_MARK) {
        extraClasses += ' false-mark';
    }
}
</script>

<div
    on:click

    on:contextmenu|preventDefault
    class={"tile " + extraClasses}
>
    {state !== TileState.HIDDEN && minesClose > 0 ? minesClose : ''}
</div>

<style>
    .tile {
        width: 100%;
        height: 100%;
        display: flex;
        justify-content: center;
        align-items: center;
        color: white;
        position: relative;
        user-select: none;
    }

    .tile.even {
        background-color: #bbb;
    }

    .tile.odd {
        background-color: #ccc;
    }


    .tile.revealed.even {
        background-color: #888;
    }

    .tile.revealed.odd {
        background-color: #999;
    }

    .tile.mark::before,
    .tile.mine::before,
    .tile.false-mark::before {
        content: '';
        position: absolute;
        width: 75%;
        height: 75%;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        border-radius: 100%;
    }

    .tile.mark::before,
    .tile.false-mark::before {
        background-color: #f59e0b;
    }

    .tile.mine::before {
        background-color: #dc2626;
    }

    .tile.false-mark::before {
        content: 'X';
        line-height: 100%;
        font-size: 100%;
        font-family: 'monospace';
        text-align: center;
        color: black;
        display: flex;
        align-items: center;
        justify-content: center;
    }
</style>
