type UnparsedFieldState = 'running' | 'won' | 'lost';
type UnparsedTileState = 'hidden' | 'revealed' | 'mark' | 'mine' | 'false_mark';

interface UnparsedTile {
    state: UnparsedTileState;
    mines_close: number;
}

interface UnparsedField {
    mines: number;
    size: number;
    mines_left: number;
    tiles: UnparsedTile[][];
    state: UnparsedFieldState;
    started_at: null | string;
    finished_at: null | string;
    recent_player: string;
}

export type Changes = [[number, number], UnparsedTile][];

export enum FieldState {
    RUNNING,
    WON,
    LOST
}

export enum TileState {
    HIDDEN,
    REVEALED,
    MARK,
    MINE,
    FALSE_MARK
}

interface Tile {
    state: TileState;
    minesClose: number;
}

export class Field {
    public mines: number;
    public size: number;
    public minesLeft: number;
    public tiles: Tile[][];
    public state: FieldState;
    public started_at: Date | null;
    public finished_at: Date | null;
    public recentPlayer: string;

    constructor({ mines, size, mines_left, tiles, state, recent_player, started_at, finished_at }: UnparsedField) {
        this.mines = mines;
        this.size = size;
        this.minesLeft = mines_left;
        this.tiles = tiles.map((row) => row.map((tile) => this.parseTile(tile)));
        this.state = this.parseFieldState(state);
        this.started_at = started_at && new Date(started_at);
        this.finished_at = finished_at && new Date(finished_at);
        this.recentPlayer = recent_player;
    }

    public handleChanges(
        {
            mines_left,
            state,
            started_at,
            finished_at,
            recent_player,
        }: Pick<UnparsedField, 'mines_left' | 'state' | 'started_at' | 'finished_at' | 'recent_player'>,
        changes: Changes
    ): void {
        this.minesLeft = mines_left;
        this.state = this.parseFieldState(state);
        this.started_at = started_at && new Date(started_at);
        this.finished_at = finished_at && new Date(finished_at);
        this.recentPlayer = recent_player;
        for (const [[row, col], tile] of changes) {
            this.tiles[row][col] = this.parseTile(tile);
        }
    }

    public playAgain({
        mines,
        size,
        mines_left,
        state,
        started_at,
        finished_at,
        recent_player
    }: Omit<UnparsedField, 'tiles'>) {
        this.mines = mines;
        this.size = size;
        this.minesLeft = mines_left;
        this.state = this.parseFieldState(state);
        this.started_at = started_at && new Date(started_at);
        this.finished_at = finished_at && new Date(finished_at);
        this.recentPlayer = recent_player;
        this.tiles = Array.from(Array(size), () =>
            Array.from(Array(size), () => ({ state: TileState.HIDDEN, minesClose: 0 }))
        );
    }

    public gameSeconds(): number {
        if (this.started_at) {
            if (this.finished_at) {
                return Math.floor((this.finished_at.getTime() - this.started_at.getTime()) / 1000);
            } else {
                return Math.floor((Date.now() - this.started_at.getTime()) / 1000);
            }
        } else {
            return 0;
        }
    }

    public isValidPosition(row: number, col: number) {
        return row >= 0 && row < this.size && col >= 0 && col < this.size;
    }

    private parseFieldState(unparsedState: UnparsedFieldState): FieldState {
        switch (unparsedState) {
            case 'running':
                return FieldState.RUNNING;
            case 'won':
                return FieldState.WON;
            case 'lost':
                return FieldState.LOST;
        }
    }

    private parseTile(unparsedTile: UnparsedTile): Tile {
        return {
            state: this.parseTileState(unparsedTile.state),
            minesClose: unparsedTile.mines_close || 0
        };
    }

    private parseTileState(unparsedState: UnparsedTileState): TileState {
        switch (unparsedState) {
            case 'hidden':
                return TileState.HIDDEN;
            case 'revealed':
                return TileState.REVEALED;
            case 'mark':
                return TileState.MARK;
            case 'mine':
                return TileState.MINE;
            case 'false_mark':
                return TileState.FALSE_MARK;
        }
    }
}
