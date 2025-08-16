# ApiOS (Project Apollo)

An LLM platform in Python and GoLang with extras

**ApiOS** (working name: *Project Apollo*) is an open-source exploration of a new kind of operating system — one where **language itself becomes the API**.  

Instead of compiling code from source, ApiOS compiles **meaning**: nouns, adjectives, and verbs become composable primitives that can dynamically generate and run nano-services.  
The long-term goal is an **OS-like shell for ideas** — where specifications written in natural language can be parsed into structured libraries, executed, and evolved.

---

## ✨ Vision

ApiOS asks: *What if an operating system was built from linguistic primitives?*

- **Nouns** → Objects, entities, persistent state.  
- **Adjectives** → Attributes and properties that can be modified.  
- **Verbs** → Nano-services (actions) that operate on nouns and alter adjectives.  

These primitives interact via a **PhraseGraph** — a semantic runtime graph where every interaction is versioned (semver) and compiled into reusable micro-libraries.

The aim is not to replace Linux, Windows, or MacOS, but to **explore a new way of thinking about computation**:  
- APIs as atoms of thought.  
- Libraries as evolving vocabularies.  
- Execution as narrative flow.  

---

## 🏗️ Architecture (Prototype Stage)

- **Core Runtime:** Python  
- **Persistence Layer:** MongoDB (for graph + document storage)  
- **Interaction Layer:** CLI + language-driven shell (future: GUI/agent layer)  
- **Services:** Verbs are nano-services, created on demand and composable into workflows.  

Over time, ApiOS may grow into an **ecosystem of open libraries**, much like Linux has distributions.

---

## 📜 License

ApiOS is released under the **Apache 2.0 License** — permissive and contributor-friendly.  
- Copyright © 2025 Nicholas Alexander.  
- Contributions remain © their respective authors but are licensed under Apache 2.0 to the project.  

This keeps ApiOS open, usable in both community and commercial projects, while ensuring credit to contributors.  

(*We may explore a copyleft alternative such as GPL in future, but Apache provides the broadest collaboration base to start.*)

---

## 🤝 Contribution Guidelines

We welcome exploration, ideas, and prototypes. ApiOS is experimental — it is as much philosophy as software.

**Contributors agree to:**
1. Follow the [Code of Conduct](CODE_OF_CONDUCT.md).  
2. Use clear commit messages (e.g., `feat: add noun-adjective parser`).  
3. Submit pull requests for all changes (no direct pushes to `main`).  
4. Document new concepts in `docs/` so others can build on them.  
5. Respect semantic versioning when introducing new verbs, nouns, or libraries.  

**Good places to start:**
- Adding a parser for nouns/adjectives/verbs.  
- Prototyping the PhraseGraph.  
- Experimenting with nano-services as verbs.  
- Writing conceptual docs (what does “execution as narrative flow” mean to you?).  

---

## 🌍 Community

This project is an open exploration, not a finished product.  
Think of ApiOS as a **collaborative lab** where developers, linguists, philosophers, and curious builders can push the boundaries of what an operating system can be.  

Discussions, ideas, and proposals live in GitHub Issues.  
Longer explorations and design notes belong in `docs/`.  

---

## 🚀 Roadmap (Early Thoughts)

- [ ] **MVP**: Python shell + MongoDB + noun/verb/adjective prototype.  
- [ ] **PhraseGraph**: first semantic graph linking entities.  
- [ ] **Nano-services**: verbs as executable units with semver.  
- [ ] **CLI Playground**: test commands in natural language.  
- [ ] **Library Evolution**: dynamic creation of semantic libraries.  
- [ ] **Agent Layer**: future exploration of AI agents running ApiOS as substrate.  

---

## 🙏 Acknowledgments

Dedicated to Nicholas Alexander’s grandfather, whose name inspired *Project Apollo*.  

ApiOS stands on the shoulders of countless open source projects, research in operating systems, knowledge graphs, and AI-driven compilers.  

---

> “An operating system of meaning, where thought itself can be compiled.”  

