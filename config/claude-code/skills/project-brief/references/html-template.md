# HTML Template Reference

This is the exact CSS and HTML component library for project briefs. Use these patterns verbatim -do not invent new styles.

## CSS Variables

```css
:root {
  --bg: #fafafa;
  --card: #ffffff;
  --border: #e0e0e0;
  --accent: #2563eb;
  --accent-light: #eff6ff;
  --text: #1a1a1a;
  --muted: #6b7280;
  --green: #059669;
  --green-light: #ecfdf5;
  --orange: #d97706;
  --orange-light: #fffbeb;
  --red: #dc2626;
  --red-light: #fef2f2;
  --purple: #7c3aed;
  --purple-light: #f5f3ff;
}
```

## Base Styles

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  background: var(--bg); color: var(--text); line-height: 1.6;
  max-width: 960px; margin: 0 auto; padding: 2rem 1.5rem;
}
h1 { font-size: 1.75rem; margin-bottom: 0.25rem; }
h2 { font-size: 1.25rem; margin-bottom: 0.75rem; color: var(--accent); border-bottom: 2px solid var(--accent); padding-bottom: 0.25rem; }
h3 { font-size: 1rem; margin-bottom: 0.5rem; }
.subtitle { color: var(--muted); font-size: 0.95rem; margin-bottom: 2rem; }
ul { padding-left: 1.25rem; }
li { margin-bottom: 0.25rem; font-size: 0.9rem; }
section { margin-bottom: 2rem; }
```

## Components

### Card
```html
<div class="card">
  <h3>Title</h3>
  <p>Content here</p>
</div>
```
```css
.card { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 1.25rem; margin-bottom: 1.25rem; }
```

### Pitch (One-Line Callout)
```html
<div class="pitch">
  I built a <strong>thing</strong> that does something impressive.
</div>
```
```css
.pitch { background: var(--accent-light); border-left: 4px solid var(--accent); padding: 1rem 1.25rem; margin-bottom: 1.5rem; border-radius: 0 8px 8px 0; font-size: 1.05rem; }
```

### Sanitize Note (Red Banner)
```html
<div class="sanitize-note">
  This document is sanitized. No company names, API keys, internal system names, or proprietary code.
  All details describe architecture, patterns, and decisions - not source code.
</div>
```
```css
.sanitize-note { background: var(--red-light); border: 1px solid var(--red); border-radius: 8px; padding: 0.75rem 1rem; font-size: 0.85rem; margin-bottom: 1.5rem; color: var(--red); font-weight: 500; }
```

### Stat Grid
```html
<div class="stat-grid">
  <div class="stat"><span class="number">42</span><span class="label">Some Metric</span></div>
  <div class="stat"><span class="number">100+</span><span class="label">Another Metric</span></div>
</div>
```
```css
.stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.75rem; margin-bottom: 1.5rem; }
.stat { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 1rem; text-align: center; }
.stat .number { font-size: 1.75rem; font-weight: 700; color: var(--accent); display: block; }
.stat .label { font-size: 0.8rem; color: var(--muted); text-transform: uppercase; letter-spacing: 0.05em; }
```

### Architecture Layers (Nested Indented Boxes)
```html
<div class="layers">
  <div class="layer layer-marketplace">
    <span class="layer-title">Top Layer</span>
    <span class="layer-desc">- Description.</span>
  </div>
  <div class="layer layer-plugin">
    <span class="layer-title">Second Layer</span>
    <span class="layer-desc">- Description.</span>
    <div class="layer-items">
      <span>item-a</span>
      <span>item-b</span>
    </div>
  </div>
  <div class="layer layer-skill">
    <span class="layer-title">Third Layer</span>
    <span class="layer-desc">- Description.</span>
  </div>
  <div class="layer layer-infra">
    <span class="layer-title">Fourth Layer</span>
    <span class="layer-desc">- Description.</span>
  </div>
</div>
```
```css
.layers { display: flex; flex-direction: column; gap: 0.5rem; margin-top: 1rem; }
.layer { border-radius: 8px; padding: 0.75rem 1rem; }
.layer-marketplace { background: #dbeafe; border: 2px solid #3b82f6; }
.layer-plugin { background: #e0e7ff; border: 2px solid #6366f1; margin-left: 1.5rem; }
.layer-skill { background: #ede9fe; border: 2px solid #8b5cf6; margin-left: 3rem; }
.layer-infra { background: #fef3c7; border: 2px solid #f59e0b; margin-left: 4.5rem; }
.layer-title { font-weight: 700; font-size: 0.85rem; display: inline-block; margin-right: 0.5rem; }
.layer-desc { font-size: 0.8rem; color: var(--muted); }
.layer-items { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.4rem; }
.layer-items span { background: rgba(255,255,255,0.7); border-radius: 4px; padding: 0.15rem 0.5rem; font-size: 0.75rem; font-family: 'SF Mono', 'Fira Code', monospace; }
```

Layer colors can be adapted per project. The 4 tiers represent conceptual depth (outermost to innermost). Use fewer layers if the project is simpler. You can rename the CSS classes contextually (e.g., `layer-api`, `layer-core`) but keep the same color progression: blue → indigo → purple → amber.

### Decision Cards (Problem/Choice/Why/Result)
```html
<div class="card">
  <h3>Decision Title</h3>
  <div class="decision">
    <span class="decision-label problem">Problem</span>
    <span class="decision-text">What was broken or needed.</span>
  </div>
  <div class="decision">
    <span class="decision-label choice">Choice</span>
    <span class="decision-text">What was decided.</span>
  </div>
  <div class="decision">
    <span class="decision-label why">Why</span>
    <span class="decision-text">The reasoning.</span>
  </div>
  <div class="decision">
    <span class="decision-label result">Result</span>
    <span class="decision-text">The outcome.</span>
  </div>
</div>
```
```css
.decision { display: grid; grid-template-columns: auto 1fr; gap: 0.5rem 1rem; margin-bottom: 0.75rem; align-items: start; }
.decision:last-child { margin-bottom: 0; }
.decision-label { font-weight: 700; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.15rem 0.5rem; border-radius: 4px; white-space: nowrap; text-align: center; min-width: 80px; }
.decision-label.problem { background: var(--red-light); color: var(--red); }
.decision-label.choice { background: var(--green-light); color: var(--green); }
.decision-label.why { background: var(--purple-light); color: var(--purple); }
.decision-label.result { background: var(--orange-light); color: var(--orange); }
.decision-text { font-size: 0.9rem; }
```

The WHY row is optional -use it for decisions where the reasoning isn't obvious from the choice alone. For simpler decisions, PROBLEM/CHOICE/RESULT is enough.

### Workflow Steps (Numbered Timeline)
```html
<div class="workflow">
  <div class="wf-step">
    <div class="wf-num">1</div>
    <div class="wf-content">
      <h4>Step Title</h4>
      <p>What happens in this step.</p>
    </div>
  </div>
  <div class="wf-step">
    <div class="wf-num">2</div>
    <div class="wf-content">
      <h4>Next Step</h4>
      <p>Description.</p>
    </div>
  </div>
</div>
```
```css
.workflow { display: flex; flex-direction: column; gap: 0; }
.wf-step { display: grid; grid-template-columns: 2rem 1fr; gap: 0.75rem; }
.wf-num { width: 2rem; height: 2rem; background: var(--accent); color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 0.8rem; z-index: 1; }
.wf-content { padding-bottom: 1rem; border-left: 2px solid var(--border); margin-left: -1.75rem; padding-left: 2.5rem; }
.wf-step:last-child .wf-content { border-left: 2px solid transparent; }
.wf-content h4 { font-size: 0.9rem; margin-bottom: 0.15rem; }
.wf-content p { font-size: 0.85rem; color: var(--muted); }
```

### System Tags (Color-Coded)
```html
<div class="systems">
  <span class="sys-tag">Default (blue)</span>
  <span class="sys-tag infra">Infrastructure (orange)</span>
  <span class="sys-tag security">Security (red)</span>
  <span class="sys-tag collab">Collaboration (green)</span>
  <span class="sys-tag ai">AI/ML (purple)</span>
</div>
```
```css
.systems { display: flex; flex-wrap: wrap; gap: 0.4rem; margin-top: 0.5rem; }
.sys-tag { background: var(--accent-light); color: var(--accent); border-radius: 4px; padding: 0.2rem 0.6rem; font-size: 0.75rem; font-weight: 600; }
.sys-tag.infra { background: var(--orange-light); color: var(--orange); }
.sys-tag.security { background: var(--red-light); color: var(--red); }
.sys-tag.collab { background: var(--green-light); color: var(--green); }
.sys-tag.ai { background: var(--purple-light); color: var(--purple); }
```

### Talking Points (Story Format)
```html
<div class="card stories">
  <h3>Story 1: "Question someone might ask"</h3>
  <div class="talk-point">
    <div class="question">The setup</div>
    <div class="answer">Context that frames the problem.</div>
  </div>
  <div class="talk-point">
    <div class="question">The problem</div>
    <div class="answer">What was broken or missing.</div>
  </div>
  <div class="talk-point">
    <div class="question">The insight</div>
    <div class="answer">The non-obvious realization that led to the solution. Use <strong>bold</strong> for the key phrase.</div>
  </div>
</div>
```
```css
.talk-point { margin-bottom: 1rem; padding-left: 1rem; border-left: 3px solid var(--border); }
.talk-point:last-child { margin-bottom: 0; }
.talk-point .question { font-weight: 600; font-size: 0.9rem; color: var(--muted); margin-bottom: 0.25rem; }
.talk-point .answer { font-size: 0.95rem; }
.talk-point .answer strong { color: var(--accent); }
.stories h3 { margin-top: 1rem; margin-bottom: 0.5rem; font-size: 0.95rem; }
.stories h3:first-child { margin-top: 0; }
```

### Pattern Grid (2x2)
```html
<div class="pattern-grid">
  <div class="pattern-box">
    <h4>Pattern Name</h4>
    <p>Brief description of the pattern and why it matters.</p>
  </div>
  <!-- repeat 2-4 times -->
</div>
```
```css
.pattern-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem; }
.pattern-box { background: var(--card); border: 1px solid var(--border); border-radius: 8px; padding: 0.75rem 1rem; }
.pattern-box h4 { font-size: 0.85rem; margin-bottom: 0.35rem; color: var(--accent); }
.pattern-box p { font-size: 0.8rem; color: var(--muted); }
```

### Note Callout (Orange)
```html
<div class="note">
  Important context or caveat.
</div>
```
```css
.note { background: var(--orange-light); border-left: 4px solid var(--orange); padding: 0.75rem 1rem; border-radius: 0 8px 8px 0; font-size: 0.85rem; margin-top: 0.75rem; }
```

### Quick Reference Table
```html
<table style="width:100%; font-size:0.85rem; border-collapse:collapse;">
  <tr style="border-bottom:1px solid var(--border);">
    <td style="padding:0.4rem 0; font-weight:600; width:35%;">Label</td>
    <td style="padding:0.4rem 0;">Value</td>
  </tr>
  <!-- last row: no border-bottom -->
  <tr>
    <td style="padding:0.4rem 0; font-weight:600;">Label</td>
    <td style="padding:0.4rem 0;">Value</td>
  </tr>
</table>
```

### Footer
```html
<footer style="text-align:center; color:var(--muted); font-size:0.75rem; margin-top:2rem; padding-top:1rem; border-top:1px solid var(--border);">
  Project brief - not for distribution. All details sanitized.
</footer>
```

## Print & Responsive

Always include these at the end of the `<style>` block:

```css
@media print {
  body { padding: 0.5rem; font-size: 0.85rem; max-width: 100%; }
  .card { break-inside: avoid; }
  h2 { break-after: avoid; }
  .stat .number { font-size: 1.25rem; }
}
@media (max-width: 600px) {
  .pattern-grid { grid-template-columns: 1fr; }
  .stat-grid { grid-template-columns: repeat(2, 1fr); }
}
```
