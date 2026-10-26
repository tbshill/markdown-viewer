# Vendored third-party files

| File | Package | Version | License |
|------|---------|---------|---------|
| `mermaid.min.js` | [mermaid](https://www.npmjs.com/package/mermaid) (`dist/mermaid.min.js`) | 11.4.1 | MIT |
| `highlight.min.js` | [@highlightjs/cdn-assets](https://www.npmjs.com/package/@highlightjs/cdn-assets) (`highlight.min.js`, common-languages build) | 11.10.0 (highlight.js) | BSD-3-Clause |

Obtained with:

```sh
npm install mermaid@11.4.1 @highlightjs/cdn-assets@11.10.0
cp node_modules/mermaid/dist/mermaid.min.js .
cp node_modules/@highlightjs/cdn-assets/highlight.min.js .
```

`markdown.css` and `viewer.js` are first-party. The highlight.js colour theme is hand-written in `markdown.css`.
