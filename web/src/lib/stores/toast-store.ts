import { writable } from 'svelte/store';

export enum ToastType {
    SUCCESS,
    INFO,
    WARNING,
    ERROR
}

interface Toast {
    id: number;
    message: string;
    type: ToastType;
    duration: number;
    timeout: NodeJS.Timeout;
}

let globalToastId = 0;

const createToastStore = () => {
    const { subscribe, update } = writable<Toast[]>([]);

    const show = (message: string, type: ToastType, duration = 5000) => {
        const id = globalToastId++;
        const timeout = setTimeout(() => hide(id), duration);
        update((toasts) => toasts.concat({ id, message, type, duration, timeout }));
    };

    const hide = (id: number) => {
        update((toasts) =>
            toasts.filter((t) => {
                if (t.id !== id) {
                    return true;
                } else {
                    clearTimeout(t.timeout);
                    return false;
                }
            })
        );
    };

    return { subscribe, show, hide };
};

export default createToastStore();
