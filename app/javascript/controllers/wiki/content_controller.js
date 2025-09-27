import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="wiki--content"
export default class extends Controller {
  static outlets = [ "wiki--toc" ]

  wikiTocOutletConnected(wikiToc) {
    wikiToc.content = this.#buildToc()
  }

  #buildToc() {
    const headings = Array.from(this.element.querySelectorAll("h1, h2, h3, h4, h5, h6"));

    if (!headings.length) return;

    const items = headings.map(heading => {
      const level = parseInt(heading.tagName[1]);
      const anchor = heading.querySelector("a.wiki-anchor");

      if (!anchor) return null;

      return {
        level,
        text: heading.childNodes[0].textContent.trim(),
        href: anchor.getAttribute("href")
      };
    }).filter(Boolean);

    return this.#buildTocTree(items, 1)
  }

  #buildTocTree(items, currentLevel) {
    const ul = document.createElement("ul");

    while (items.length) {
      const item = items[0];

      if (item.level < currentLevel) break

      if (item.level === currentLevel) {
        items.shift();

        const li = document.createElement("li");
        const a = document.createElement("a");

        a.href = item.href;
        a.textContent = item.text;
        li.appendChild(a);
        ul.appendChild(li);

        continue
      }

      if (item.level > currentLevel) {
        const childUl = this.#buildTocTree(items, item.level);
        ul.lastElementChild.appendChild(childUl);
      }
    }
    return ul;
  }
}
