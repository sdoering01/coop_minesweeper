<script lang="ts">
    import { fly } from 'svelte/transition';
    import MdClose from 'svelte-icons/md/MdClose.svelte'

    import toasts, { ToastType } from '$lib/stores/toast-store'

    // TODO: Check whether classes are purged after building
    const classes = {
        [ToastType.SUCCESS]: 'bg-success',
        [ToastType.INFO]: 'bg-info',
        [ToastType.WARNING]: 'bg-warning',
        [ToastType.ERROR]: 'bg-error'
    }
</script>

<div class="fixed flex justify-center inset-x-0 bottom-0 pointer-events-none p-4 max-w-[100rem] mx-auto sm:justify-end md:p-6">
    <div class="space-y-2 w-full max-w-[16rem]">
        {#each $toasts as { id, message, type }}
            <div in:fly={{duration: 300, x: 10 }} class="items-center flex p-2 rounded-md pointer-events-auto text-black shadow-md {classes[type]}">
                <div class="flex-1">
                    { message }
                </div>
                <button on:click={() => toasts.hide(id)} class="p-1 text-neutral hover:text-base-300">
                    <span class="icon m-0"><MdClose /></span>
                </button>
            </div>
        {/each}
    </div>
</div>
