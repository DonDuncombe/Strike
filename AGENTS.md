# Strike coding guidance

Use [AGENT_godot.md](AGENT_godot.md) for the project's Godot workflow and [godot_4_7_reference.md](godot_4_7_reference.md) as the local Godot API reference. Record engine behavior that has been verified in this project, such as draw-order rules, in [godot_verified_notes.md](godot_verified_notes.md); check it before adding new visual elements. These rules apply to code created or changed in this repository.

## Godot and GDScript

- Target Godot 4.7.1 and modern GDScript. Do not introduce Godot 3.x syntax or APIs.
- Write clear, typed GDScript for parameters, returns, and variables where the type is known. Keep code concise and organized around the scene or resource that owns the behavior.
- When using an unfamiliar or version-sensitive Godot class, method, property, signal, annotation, or enum, search the relevant section of `godot_4_7_reference.md` and check its signature and behavior before coding. Search targeted sections; the reference is too large to load wholesale.
- Prefer the local reference and the installed Godot 4.7.1 executable for Godot API questions. Avoid third-party examples that may use older engine versions. If the local reference and installed engine disagree, treat the running 4.7.1 engine as authoritative and explain the discrepancy.
- Check nontrivial vector math, coordinate-space conversions, and data-structure logic with a concrete example or calculation before implementing them.

## Project behavior

- Preserve existing scene paths, input action names, and public signals unless the requested change requires updating their callers.
- Keep player movement values tunable through exports where designers need to adjust feel. Keep unlockable abilities gated by their progression flags and runtime unlock API.
- Make changes in the relevant script or scene rather than adding abstractions without a current use.

## Save command

- When the user types `save as "x"`, treat the text inside the quotes as the save name. Stage all current changes, commit them with that name as the commit message, and push the current branch to `origin`.
- Before committing, check `git status`. If there is nothing to commit and nothing unpushed, do not create an empty commit. Tell the user the codebase version is up to date.
- If there is nothing new to commit but local commits have not been pushed, push them and report that.

## Verification and communication

- After changing GDScript or scenes, run a Godot 4.7.1 headless project load. For gameplay changes, also run a short headless startup check and identify behavior that still needs a manual playtest.
- In answers containing GDScript examples, give code that matches the project and briefly explain the important logic and relevant Godot API properties beneath it. For repository edits, report what changed and how it was verified.
