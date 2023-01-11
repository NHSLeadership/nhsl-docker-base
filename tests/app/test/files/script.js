const para1 = document.getElementById("js");

animate(para1);

function animate(element) {
    let elementWidth = element.offsetWidth;
    let parentWidth = element.parentElement.offsetWidth;
    let flag = 0;
    setInterval(() => {
        element.style.marginLeft = --flag + "px";
        if (elementWidth == -flag) {
            flag = parentWidth;
        }
    }, 10);
}