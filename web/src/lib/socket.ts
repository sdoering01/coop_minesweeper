import { browser } from '$app/env';
import { Socket } from 'phoenix';

import { backendSocketUrl } from '$lib/config';

export const socket = browser ? new Socket(backendSocketUrl) : null;

if (browser) {
    console.log('Connecting to socket on url', backendSocketUrl);
    socket.connect();
    socket.onOpen(() => console.log('Connected to socket'));
}
