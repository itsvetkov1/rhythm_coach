## Quick Reference

**Purpose:** Evaluate and recommend the best approach for building a real-time AI assistant that recognizes musical structure patterns (chords, melody, rhythm) for a small team.

**Output:** Ranked list of 5 approaches with opensource tool scan, implementation path for top choice, and data collection plan.

**Key Requirements:**
- Scan opensource tools FIRST before proposing approaches
- All 5 approaches must support real-time feedback (low latency)
- Optimize for 3-person team (2 musicians, 1 dev) with MVP dataset (minimum viable, scalable to 500+ samples)
- Include specific tool/library/model names (not generic architecture descriptions)
- Rank by quality-efficiency tradeoff: musical structure recognition accuracy vs team effort + compute cost

**Critical Rules:**
- Real-time capability is MANDATORY (exclude batch-only approaches)
- Focus on musical structure (chords, melody, rhythm) - not generic audio classification
- Must be feasible without extensive ML infrastructure or expertise
- No proprietary models, cloud-only solutions, or approaches requiring >1000 samples for MVP

---

## Full Specification

**CONTEXT:**
Build an AI assistant that analyzes musical structure patterns (chord progressions, melodic motifs, rhythmic patterns) and provides real-time feedback during performance or recording. Team consists of 2 musicians and 1 developer with limited ML infrastructure. Starting with MVP using minimum viable dataset, can scale to 500+ recorded samples. Need approach that balances recognition quality with implementation efficiency for a small team.

**ROLE:**
You are an AI/ML engineer specializing in music information retrieval (MIR) and real-time audio processing. You have expertise in evaluating opensource audio ML tools, model architectures for musical structure analysis, and training strategies optimized for small teams without dedicated ML infrastructure.

**ACTION:**

1. **Scan opensource landscape**
   - Search for pretrained models and tools for musical structure recognition (chord detection, melody transcription, rhythm analysis)
   - Evaluate each on: model availability, fine-tuning ease, real-time capability, team-friendliness, quality of pretrained performance
   - Present findings in table format: Tool | Pretrained Capability | Fine-tunable | Real-time | Team-Friendly | Notes

2. **Identify and rank 5 viable approaches**
   For each approach provide:
   - **Name & Overview** (2-3 sentences explaining the core technique)
   - **Opensource Baseline** (specific tool/model name, or "custom build" with architecture details)
   - **Training Strategy** (pretrained+finetune / train from scratch / heavy augmentation / hybrid)
   - **Minimum Data for MVP** (number of samples, required variations, recording specifics)
   - **Real-time Feasibility** (expected latency in ms, compute requirements, optimization needs)
   - **Team Effort** (developer hours for implementation, musician hours for recording, ongoing maintenance)
   - **Quality-Efficiency Tradeoff** (where approach excels, where it compromises, failure modes)

   Rank approaches using:
   - **Primary criterion:** Accuracy/quality of musical structure recognition (chord correctness, melody transcription accuracy, rhythm precision)
   - **Secondary criterion:** Total efficiency (developer time + musician recording time + compute cost)
   - Use scoring format: Approach Name - [Quality: X/10] - [Efficiency: Y/10]

3. **Provide detailed MVP implementation path for top-ranked approach**
   Include:
   - Specific model/architecture recommendation with justification
   - Step-by-step implementation guide (tools, libraries, code structure)
   - Technical requirements (hardware, dependencies, environment setup)
   - Integration strategy for real-time feedback loop
   - Testing and validation approach

4. **Create data collection plan**
   Specify:
   - What to record (musical elements, instruments, performance contexts)
   - How many samples minimum for MVP and optimal for production
   - Required variations (keys, tempos, dynamics, articulations, playing styles)
   - Recording specifications (format, sample rate, bit depth, mono/stereo)
   - Annotation requirements (labels, ground truth, metadata)
   - Data augmentation techniques to multiply effective dataset size

5. **Define success metrics and expectations**
   - Quantitative: accuracy percentages, F1 scores, latency targets
   - Qualitative: what "good enough" looks like for MVP vs production
   - Common failure modes and how to recognize them
   - When to consider the approach successful vs when to pivot

**FORMAT:**

```markdown
## Opensource Tools Landscape

| Tool/Model | Pretrained For | Fine-tunable | Real-time | Team-Friendly | Assessment |
|------------|----------------|--------------|-----------|---------------|------------|
| [name]     | [capability]   | Yes/No       | Yes/No    | Yes/No        | [1-line]   |

## Top 5 Approaches (Ranked)

### 1. [Approach Name] - Quality: X/10 - Efficiency: Y/10

**Overview:** [2-3 sentence description of core technique]

**Opensource Baseline:** [Specific tool/model name OR "Custom build: [architecture]"]

**Training Strategy:** [Detailed strategy with rationale]

**Minimum Data for MVP:**
- Samples: [number]
- Variations: [specific musical variations needed]
- Recording specs: [format, sample rate, etc.]

**Real-time Feasibility:**
- Expected latency: [X ms]
- Compute: [CPU/GPU requirements]
- Optimizations: [techniques for real-time performance]

**Team Effort:**
- Dev implementation: [X hours]
- Musician recording: [Y hours]
- Maintenance: [ongoing effort estimate]

**Quality-Efficiency Tradeoff:**
- Excels at: [specific strengths]
- Compromises on: [specific weaknesses]
- Failure modes: [when/how it breaks]

---

[Repeat structure for approaches 2-5]

## Recommended MVP Implementation (Approach #1)

**Chosen Approach:** [Name from #1 above]

**Why This Approach:** [2-3 sentences on why it's optimal for this team/use-case]

**Architecture/Model:** [Specific technical details]

**Step-by-Step Implementation:**
1. [Setup step with specific tools/commands]
2. [Data preparation step with code snippets or references]
3. [Training/fine-tuning step with hyperparameters]
4. [Real-time integration step with latency optimization]
5. [Testing and validation step with metrics]

**Technical Requirements:**
- Hardware: [minimum specs]
- Software: [dependencies, libraries, frameworks]
- Environment: [OS, Python version, etc.]

**Data Collection Plan:**

*For Musicians:*
- Record: [specific musical elements - e.g., "50 different chord progressions, each in 3 keys"]
- Variations needed: [e.g., "play at slow/medium/fast tempo, clean/distorted tone, fingerpicked/strummed"]
- Duration per sample: [X seconds]
- Total recording time: [Y hours]

*Technical Specs:*
- Format: [WAV/FLAC/etc.]
- Sample rate: [44.1kHz/48kHz]
- Bit depth: [16/24-bit]
- Channels: [mono/stereo and why]

*Minimum Dataset:*
- MVP: [X samples]
- Optimal: [Y samples]

*Data Augmentation:*
- Techniques: [pitch shifting, time stretching, noise injection, etc.]
- Multiplier effect: [effective dataset size]

**Expected Results:**

*Quantitative:*
- Chord recognition accuracy: [X%]
- Melody transcription F1: [X]
- Rhythm detection precision: [X%]
- Real-time latency: [X ms]

*Qualitative:*
- MVP "good enough" = [description of acceptable performance]
- Production ready = [description of target performance]

*Failure Modes:*
- Struggles with: [specific musical contexts]
- Workarounds: [how to mitigate failures]

## Decision Criteria for Next Steps

- If results meet MVP threshold → [scale data collection, refine model]
- If results below threshold → [try approach #2, adjust data strategy, revisit requirements]
- If real-time performance insufficient → [optimization techniques, hardware upgrade, architecture change]
```

**TARGET AUDIENCE:**
- **Primary:** Developer (needs implementation specifics, code references, architecture details, technical requirements)
- **Secondary:** Musicians (needs recording guidance, quality expectations, musical terminology for what to capture)

Both audiences should understand: what they're building, why it works, what's expected of them, and how to measure success.

**CONSTRAINTS:**

*Must Include:*
- Opensource tool scan BEFORE listing the 5 approaches
- Specific tool/library/model names (not "use a CNN" - say "use Magenta's Onsets and Frames model")
- Real-time latency estimates in milliseconds
- Concrete data requirements (not "some audio files" - say "50 chord progressions, 3 variations each")
- Musical structure focus: chord detection, melody transcription, rhythm analysis

*Must Exclude:*
- Approaches requiring >1000 samples for minimum viable results
- Batch-processing-only methods (cannot give real-time feedback)
- Proprietary models or cloud-only solutions (not opensource/self-hosted)
- Generic audio classification without musical structure specificity
- Solutions requiring extensive ML expertise or infrastructure
- Approaches needing expensive hardware (>$2000 GPU requirement)
- Proprietary datasets or API dependencies

*Quality Gates:*
- Every approach must be implementable by a single developer in <100 hours
- Every approach must be testable with <500 recorded samples
- Every approach must achieve <100ms latency for real-time feedback
- Every recommendation must cite specific opensource tools/papers/codebases
