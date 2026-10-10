import { marked } from "marked";

class Markdown extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    this.outerHTML = `
    <div class="prose prose-zinc max-w-none">
      ${marked.parse(this.textContent)}
    </div>
    `;
  }
}

customElements.define("markdown-block", Markdown);
