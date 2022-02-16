let elementsShown = 0;

export const hideBodyOverflow = (_el: HTMLElement) => {
    if (elementsShown === 0) {
        document.body.classList.add('overflow-hidden');
    }
    elementsShown++;

    return {
        destroy() {
            elementsShown--;
            if (elementsShown === 0) {
                document.body.classList.remove('overflow-hidden');
            }
        }
    };
};
