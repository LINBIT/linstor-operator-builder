addEventListener("DOMContentLoaded", (event) => {
    let charts = document.getElementById("charts");

    fetch("./index.yaml")
        .then((resp) => {
            return resp.text();
        })
        .then((content) => {
            let index = jsyaml.load(content);
            for (const [key, value] of Object.entries(index.entries).toSorted()) {
                let first = value[0];
                let card = document.createElement("aside");
                card.innerHTML = `
                    <h3>${key}</h3>
                    <p>${first.description}</p>
                    <dl>
                        <dt>Version</dt><dd>${first.version}</dd>
                        <dt>App-Version</dt><dd>${first.appVersion}</dd>
                        <dialog>sadasdfas</dialog>
                    </dl>
                `;
                charts.appendChild(card);
            }
        });
});
