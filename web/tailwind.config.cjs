module.exports = {
    content: ['./src/**/*.{html,js,svelte,ts}'],
    theme: {
        extend: {
            screens: {
                'xs': '480px'
            }
        },
    },
    plugins: [
        require('daisyui')
    ]
}
