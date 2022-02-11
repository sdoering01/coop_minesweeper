<script lang="ts">
    import { onMount } from 'svelte';
    import type { Channel } from 'phoenix';

    import { Field, TileState, Changes, FieldState } from '$lib/Field';

    export let field: Field;
    export let tileSize = 30;
    export let channel: Channel;
    export let joined: boolean;

    let canvas: HTMLCanvasElement;
    let container: HTMLDivElement;
    let context: CanvasRenderingContext2D;

    let hovering = false;
    let hoverRow = 0;
    let hoverCol = 0;

    let dragging = false;
    let dragPos = { top: 0, left: 0, x: 0, y: 0 };

    onMount(() => {
        context = canvas.getContext('2d');
        context.textAlign = 'center';
        context.textBaseline = 'middle';
        repaint();
    });

    $: if (field.state !== FieldState.RUNNING && hovering) {
        repaintTile(hoverRow, hoverCol, false);
        hovering = false;
    }

    $: interactive = joined && field.state === FieldState.RUNNING;

    export const paintChanges = (changes: Changes) => {
        const start = Date.now();
        changes.forEach(([[row, col], _]) => {
            repaintTile(row, col);
            if (hovering && hoverRow === row && hoverCol === col) {
                hovering = false;
            }
        });
        console.log(`Paint changes took ${Date.now() - start}ms`);
    };

    export const repaint = () => {
        if (context) {
            const start = Date.now();
            context.fillStyle = 'black';
            for (let row = 0; row < field.size; row++) {
                for (let col = 0; col < field.size; col++) {
                    repaintTile(row, col);
                }
            }
            console.log(`Repaint took ${Date.now() - start}ms`);
        }
    };

    const repaintTile = (row: number, col: number, hoverEffect: boolean = false) => {
        const tile = field.tiles[row][col];

        if (hoverEffect)
            if (tile.state === TileState.HIDDEN || tile.state === TileState.MARK) {
                context.fillStyle = '#ddd';
            } else {
                return;
            }
        else if (((row % 2) + col) % 2 === 0) {
            context.fillStyle = tile.state === TileState.REVEALED ? '#888' : '#bbb';
        } else {
            context.fillStyle = tile.state === TileState.REVEALED ? '#999' : '#ccc';
        }

        context.fillRect(col * tileSize, row * tileSize, tileSize, tileSize);

        if (tile.state === TileState.REVEALED && tile.minesClose > 0) {
            context.fillStyle = 'black';
            context.fillText(
                tile.minesClose.toString(),
                (col + 0.5) * tileSize,
                (row + 0.5) * tileSize
            );
        } else if (
            tile.state === TileState.MARK ||
            tile.state === TileState.FALSE_MARK ||
            tile.state === TileState.MINE
        ) {
            context.fillStyle = tile.state === TileState.MINE ? '#dc2626' : '#f59e0b';

            const cx = (col + 0.5) * tileSize;
            const cy = (row + 0.5) * tileSize;

            context.beginPath();
            context.arc(cx, cy, 0.375 * tileSize, 0, 2 * Math.PI);
            context.fill();

            if (tile.state === TileState.FALSE_MARK) {
                context.fillStyle = 'black';
                context.fillText('X', cx, cy);
            }
        }
    };

    const handleMouseMove = (ev: MouseEvent) => {
        if (dragging) {
            const dx = ev.clientX - dragPos.x;
            const dy = ev.clientY - dragPos.y;
            container.scrollTop = dragPos.top - dy;
            container.scrollLeft = dragPos.left - dx;
        } else if (interactive) {
            const col = Math.floor(ev.offsetX / tileSize);
            const row = Math.floor(ev.offsetY / tileSize);
            if (field.isValidPosition(row, col)) {
                if (hovering && row === hoverRow && col === hoverCol) {
                    return;
                }
                if (hovering) {
                    repaintTile(hoverRow, hoverCol, false);
                }
                hovering =
                    field.tiles[row][col].state === TileState.HIDDEN ||
                    field.tiles[row][col].state === TileState.MARK;
                if (hovering) {
                    repaintTile(row, col, true);
                    hoverRow = row;
                    hoverCol = col;
                }
            }
        }
    };

    const handleMouseLeave = () => {
        if (interactive && hovering) {
            repaintTile(hoverRow, hoverCol, false);
            hovering = false;
        }
        dragging = false;
    };

    const handleReveal = (ev: MouseEvent) => {
        const col = Math.floor(ev.offsetX / tileSize);
        const row = Math.floor(ev.offsetY / tileSize);
        if (field.isValidPosition(row, col) && field.tiles[row][col].state === TileState.HIDDEN) {
            channel.push('tile:reveal', { row, col }).receive('error', ({ reason }) => {
                console.log(`Could not reveal tile in row ${row} and col ${col}: ${reason}`);
            });
        }
    };

    const handleToggle = (ev: MouseEvent) => {
        const col = Math.floor(ev.offsetX / tileSize);
        const row = Math.floor(ev.offsetY / tileSize);
        if (
            field.isValidPosition(row, col) &&
            (field.tiles[row][col].state === TileState.HIDDEN ||
                field.tiles[row][col].state === TileState.MARK)
        ) {
            channel.push('tile:toggle', { row, col }).receive('error', ({ reason }) => {
                console.log(`Could not toggle tile in row ${row} and col ${col}: ${reason}`);
            });
        }
    };

    const handleMouseDown = (ev: MouseEvent) => {
        if (ev.button === 1) {
            dragging = true;
            dragPos = {
                left: container.scrollLeft,
                top: container.scrollTop,
                x: ev.clientX,
                y: ev.clientY
            };
        }
    };

    const handleMouseUp = (ev: MouseEvent) => {
        if (ev.button === 1) {
            dragging = false;
        }
    };
</script>

<div class="scroll-container w-auto max-w-full max-h-full overflow-auto" bind:this={container}>
    <div class="p-2 w-fit bg-black">
        <canvas
            style:cursor={dragging ? 'grabbing' : hovering ? 'pointer' : 'auto'}
            bind:this={canvas}
            on:mousedown={handleMouseDown}
            on:mouseup={handleMouseUp}
            on:mousemove={handleMouseMove}
            on:mouseleave={handleMouseLeave}
            on:click={interactive && handleReveal}
            on:contextmenu|preventDefault={interactive && handleToggle}
            width={field.size * tileSize}
            height={field.size * tileSize}
        />
    </div>
</div>

<style>
    .scroll-container {
        --scrollbar-bg: hsla(var(--b2));
        --scrollbar-fg: hsla(var(--b3));
        --scrollbar-size: 11px;
        /* Firefox */
        scrollbar-width: var(--scrollbar-size);
        scrollbar-color: var(--scrollbar-fg) var(--scrollbar-bg);
    }

    .scroll-container::-webkit-scrollbar {
        width: var(--scrollbar-size);
        height: var(--scrollbar-size);
    }

    .scroll-container::-webkit-scrollbar-thumb {
        background-color: var(--scrollbar-fg);
        border-radius: 6px;
        border: solid 3px var(--scrollbar-bg);
    }

    .scroll-container::-webkit-scrollbar-track {
        background-color: var(--scrollbar-bg);
    }

    .scroll-container::-webkit-scrollbar-corner {
        background-color: var(--scrollbar-bg);
    }
</style>
