# Third-party notices

## Matt Pocock skills

`skills/grill-me`, `skills/grill-with-docs`, `skills/grilling`, `skills/domain-modeling`, and `skills/to-spec` are adapted from [mattpocock/skills](https://github.com/mattpocock/skills), using the local snapshot in `~/skills-db/mattpocock` on September 12, 2026.

Batman keeps canonical `SKILL.md` files valid for Codex by expressing manual-only invocation in `agents/openai.yaml`. The installer generates Copilot-specific installed copies with the source `disable-model-invocation` frontmatter restored. It also replaces the two wrapper skills' host-specific `Skill` tool calls with equivalent sibling file references so the composition works without that tool. The shared skill instructions and supporting files are otherwise unchanged.

MIT License

Copyright (c) 2026 Matt Pocock

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## pstack unslop

`skills/unslop` is copied from [pstack](https://github.com/cursor/plugins/tree/main/pstack), using the local snapshot in `~/skills-db/pstack` on September 12, 2026. Batman keeps the canonical `SKILL.md` valid for Codex by moving manual-only invocation to `agents/openai.yaml`; the installer restores `disable-model-invocation` in Copilot's installed copy. The skill instructions are unchanged.

MIT License

Copyright (c) 2026 Lauren Tan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
