import { browser } from '$app/env';
import { Socket } from 'phoenix';

import { backendSocketUrl } from '$lib/config';

export const socket = browser ? new Socket(backendSocketUrl) : null;

if (browser) {
    socket.connect();
}
