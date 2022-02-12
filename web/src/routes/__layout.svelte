<script lang="ts">
    import '../app.css';

    import ToastContainer from '$components/ToastContainer.svelte';
</script>

<main class="relative">
    <slot />
    <ToastContainer />
</main>
