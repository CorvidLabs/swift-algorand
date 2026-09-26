/**
 * Renders docs/HLD.md to a standalone HTML page that GitHub Pages serves next to the DocC archive.
 *
 * DocC cannot render Mermaid, so the design document is published as a sibling page instead of a
 * DocC article. Markdown is rendered with Bun's built-in renderer, ```mermaid fences become
 * <pre class="mermaid"> blocks that Mermaid renders in the browser, and repository-relative links
 * are rewritten to GitHub so they keep working from the Pages site.
 *
 * Usage: bun scripts/render-hld.ts [input.md] [output.html]
 */

const [input = "docs/HLD.md", output = ".build/pages/architecture/index.html"] = Bun.argv.slice(2);

const repositoryURL = "https://github.com/CorvidLabs/swift-algorand";
const sourceBaseURL = `${repositoryURL}/blob/main/docs/`;
const commit = process.env.GITHUB_SHA ?? "";

const escapeHTML = (text: string): string =>
    text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

const markdown = await Bun.file(input).text();
const title = markdown.match(/^# (.+)$/m)?.[1]?.trim() ?? "Architecture";

let body = Bun.markdown.html(markdown, { headings: { ids: true } });

// Mermaid fences: Mermaid decodes the escaped text itself, so the content is kept as rendered.
body = body.replace(
    /<pre><code class="language-mermaid">([\s\S]*?)<\/code><\/pre>/g,
    (_match: string, source: string) => `<pre class="mermaid" tabindex="0">${source}</pre>`,
);

// Other code blocks can scroll sideways, so they must be reachable by keyboard.
body = body.replaceAll("<pre><code", '<pre tabindex="0"><code');

// Wide tables scroll inside a focusable region instead of widening the page. Each region is
// labelled with its number and the heading it sits under, so every landmark name is unique.
let heading = title;
let tableNumber = 0;
body = body.replace(/<h[1-6] id="[^"]*">([\s\S]*?)<\/h[1-6]>|<table>|<\/table>/g, (match: string, text?: string) => {
    if (text !== undefined) {
        heading = text.replace(/<[^>]+>/g, "");
        return match;
    }
    if (match === "</table>") {
        return "</table></div>";
    }
    tableNumber += 1;
    const label = escapeHTML(`Table ${tableNumber}: ${heading}`);
    return `<div class="table-scroll" role="region" aria-label="${label}" tabindex="0"><table>`;
});

// Repository-relative links point at GitHub; absolute URLs and in-page anchors are left alone.
body = body.replace(/href="([^"]*)"/g, (match: string, href: string) => {
    if (href.startsWith("#") || /^[a-z][a-z0-9+.-]*:/i.test(href)) {
        return match;
    }
    return `href="${new URL(href, sourceBaseURL).href}"`;
});

const provenance = commit
    ? `Generated from <a href="${repositoryURL}/blob/${commit}/docs/HLD.md">docs/HLD.md</a> at ` +
      `<a href="${repositoryURL}/commit/${commit}"><code>${commit.slice(0, 7)}</code></a>.`
    : `Generated from <a href="${repositoryURL}/blob/main/docs/HLD.md">docs/HLD.md</a>.`;

const page = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="How the swift-algorand SDK works end to end, with diagrams.">
<title>${escapeHTML(title)}</title>
<style>
:root {
    color-scheme: light dark;
    --bg: #ffffff;
    --fg: #1f2328;
    --muted: #59636e;
    --link: #0969da;
    --border: #d1d9e0;
    --code-bg: #f6f8fa;
    --header-bg: #f6f8fa;
}
@media (prefers-color-scheme: dark) {
    :root {
        --bg: #0d1117;
        --fg: #e6edf3;
        --muted: #9198a1;
        --link: #4493f8;
        --border: #3d444d;
        --code-bg: #151b23;
        --header-bg: #151b23;
    }
}
* { box-sizing: border-box; }
html { background: var(--bg); }
body {
    margin: 0;
    background: var(--bg);
    color: var(--fg);
    font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
}
a { color: var(--link); }
a:focus-visible, [tabindex]:focus-visible { outline: 2px solid var(--link); outline-offset: 2px; }
.skip-link { position: absolute; left: 16px; top: -48px; padding: 8px 12px; background: var(--bg); color: var(--link); }
.skip-link:focus { top: 8px; }
header, main, footer { max-width: 980px; margin: 0 auto; padding: 0 16px; }
.site-header { background: var(--header-bg); border-bottom: 1px solid var(--border); }
.site-header nav { max-width: 980px; margin: 0 auto; padding: 12px 16px; display: flex; flex-wrap: wrap; gap: 8px 20px; }
.site-header .name { font-weight: 600; color: var(--fg); text-decoration: none; margin-right: auto; }
main { padding-top: 8px; padding-bottom: 48px; overflow-wrap: anywhere; }
h1, h2, h3 { line-height: 1.25; }
h2 { margin-top: 2.2em; padding-bottom: 0.3em; border-bottom: 1px solid var(--border); }
code { font: 0.9em ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; background: var(--code-bg); padding: 0.1em 0.3em; border-radius: 4px; }
pre { background: var(--code-bg); padding: 12px 16px; border-radius: 6px; overflow-x: auto; }
pre code { background: none; padding: 0; }
pre.mermaid { background: none; text-align: center; border: 1px solid var(--border); }
/* Diagrams may be wider than the text column: let them use the viewport (up to 1600px) before scrolling. */
pre.mermaid {
    width: min(100vw - 32px, 1600px);
    max-width: none;
    position: relative;
    left: 50%;
    transform: translateX(-50%);
}
.table-scroll { overflow-x: auto; margin: 1em 0; overflow-wrap: normal; }
table { border-collapse: collapse; width: 100%; font-size: 0.95em; }
th, td { border: 1px solid var(--border); padding: 6px 10px; text-align: left; vertical-align: top; }
th { background: var(--header-bg); }
footer { border-top: 1px solid var(--border); padding-top: 16px; padding-bottom: 32px; color: var(--muted); font-size: 0.9em; }
</style>
</head>
<body>
<a class="skip-link" href="#content">Skip to content</a>
<header class="site-header">
<nav aria-label="Site">
<a class="name" href="../">swift-algorand</a>
<a href="../documentation/algorand/">API reference</a>
<a href="${repositoryURL}">GitHub</a>
</nav>
</header>
<main id="content">
<noscript><p>The diagrams on this page are drawn with JavaScript. Without it, their Mermaid source is shown instead; GitHub also renders them in <a href="${repositoryURL}/blob/main/docs/HLD.md">docs/HLD.md</a>.</p></noscript>
${body}
</main>
<footer>
<p>${provenance}</p>
</footer>
<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
// Sequence diagrams keep their natural width and scroll, so their text stays readable. The dark
// theme's default edge-label background is too light for its text, so it is darkened for contrast.
mermaid.initialize({
    startOnLoad: true,
    sequence: { useMaxWidth: false },
    ...(dark
        ? { theme: "dark", themeVariables: { edgeLabelBackground: "#262c36" } }
        : { theme: "neutral" }),
});
</script>
</body>
</html>
`;

await Bun.write(output, page);
console.log(`Rendered ${input} to ${output}`);
