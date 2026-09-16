# Third-party notices

## Matt Pocock skills

`skills/grill-me`, `skills/grill-with-docs`, `skills/grilling`, `skills/domain-modeling`, `skills/to-spec`, `skills/to-tickets`, `skills/implement`, `skills/tdd`, and `skills/code-review` are adapted from [mattpocock/skills](https://github.com/mattpocock/skills). They use the local snapshot in `~/skills-db/mattpocock` from September 12, 2026.

`skills/experimental/prototype` is an unmodified copy of `skills/engineering/prototype` from the same repository at commit [`959a8e9f1edc3adbe2f7e3054bb6fbefa6696260`](https://github.com/mattpocock/skills/commit/959a8e9f1edc3adbe2f7e3054bb6fbefa6696260). Its `agents/openai.yaml` also comes from upstream. Batman records and checks the copied directory's content hash in `skills/experimental/sources.tsv`.

Batman keeps every stable skill manual-only and lets the installer derive target-specific invocation metadata. It replaces host-specific skill calls with sibling file references where the workflow requires another included skill. The implementation skill does not commit without explicit permission, and code review keeps delegation under user control.

Tracker setup references were adapted so the stable skills can use local files or an already configured tracker without requiring Matt's setup skill. Other shared instructions and supporting files remain close to the source. Batman changes only installed projections of the experimental prototype by adding target-specific manual-only invocation metadata. It does not change the vendored source.

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

## pstack skills

`skills/unslop` is adapted from [pstack](https://github.com/cursor/plugins/tree/main/pstack), using the local snapshot in `~/skills-db/pstack` on September 12, 2026. Batman narrows its description to durable human-facing prose; the rule body is unchanged. `skills/bro` was supplied from the same project by the repository owner on September 15, 2026 and is unchanged.

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
