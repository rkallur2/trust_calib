;; Robot-Human Team Dynamics Model v5
;; Corrected implementation matching paper equations
;; Changes from v4 documented inline with ;; [v5 CHANGE] comments

globals [
  total-tasks-completed
  team-efficiency
  average-trust
  communication-events
  task-failure-rate  ;; count of failures
  max-stress-overall
]

;; Define agent types
breed [humans human]
breed [robots robot]
breed [tasks task]

;; Human properties
humans-own [
  trust-in-robots      ;; [0, 100] — trust level
  workload             ;; current task load (number of difficulty-weighted tasks)
  expertise            ;; skill level 0-100 (FIXED capability, not degraded by stress)
  base-expertise       ;; [v5 CHANGE] store original expertise for reference
  stress-level         ;; [0, 100] — bounded stress
  assigned-task        ;; current task
]

;; Robot properties
robots-own [
  reliability          ;; 0-100 probability of success
  autonomy-level       ;; 0-100 — [v5 CHANGE] now affects task-taking independence
  transparency         ;; 0-100 how well it explains actions
  capability           ;; skill level 0-100
  battery-level        ;; 0-100
  assigned-task        ;; current task
  communication-frequency ;; how often it updates humans
]

;; Task properties
tasks-own [
  difficulty           ;; 10-99
  requires-collaboration ;; boolean
  time-remaining       ;; ticks to complete
  assigned-to          ;; agent working on it
]

;; ========================================================================
;; SETUP
;; ========================================================================

to setup
  clear-all

  ;; Create humans
  create-humans num-humans [
    set shape "person"
    set color blue
    set size 1.5
    set trust-in-robots initial-trust
    set workload 0
    set expertise 50 + random 50          ;; U(50, 99)
    set base-expertise expertise           ;; [v5 CHANGE] preserve original
    set stress-level random 30             ;; U(0, 29)
    set assigned-task nobody
    setxy random-xcor random-ycor
  ]

  ;; Create robots
  create-robots num-robots [
    set shape "circle"
    set color gray
    set size 1.5
    set reliability robot-reliability
    set autonomy-level robot-autonomy
    set transparency robot-transparency
    set capability 60 + random 40          ;; U(60, 99)
    set battery-level 100
    set assigned-task nobody
    set communication-frequency robot-comm-frequency
    setxy random-xcor random-ycor
  ]

  ;; Initialize tasks
  generate-tasks

  ;; Set initial globals
  set total-tasks-completed 0
  set team-efficiency 0
  set average-trust mean [trust-in-robots] of humans
  set communication-events 0
  set task-failure-rate 0
  set max-stress-overall 0

  reset-ticks
end

;; ========================================================================
;; TASK GENERATION
;; ========================================================================

;; Generate new tasks
;; Distribution: difficulty ~ U(10, 99), collaboration ~ Bernoulli(collaboration-rate/100)
;; Duration: U(50, 199) ticks
;; Arrival: batch replenishment every 50 ticks when count drops below initial-tasks
to generate-tasks
  create-tasks initial-tasks [
    set shape "box"
    set color yellow
    set size 0.8
    set difficulty 10 + random 90               ;; U(10, 99)
    set requires-collaboration (random 100 < collaboration-rate)  ;; Bernoulli
    set time-remaining 50 + random 150           ;; U(50, 199) ticks
    set assigned-to nobody
    setxy random-xcor random-ycor
    if requires-collaboration [set color orange]
  ]
end

;; ========================================================================
;; MAIN LOOP
;; ========================================================================

to go
  if ticks >= max-ticks [
    stop
  ]

  ;; Update human states and behavior
  ask humans [
    update-human-state
    ifelse assigned-task = nobody [
      find-task
    ] [
      work-on-task
    ]
  ]

  ;; Update robot states and behavior
  ask robots [
    update-robot-state
    ifelse assigned-task = nobody [
      find-task
    ] [
      work-on-task
    ]
  ]

  ;; Handle collaboration
  handle-collaboration

  ;; Update trust based on interactions
  update-trust-dynamics

  ;; Handle completed tasks
  ask tasks with [time-remaining <= 0] [
    complete-task
  ]

  ;; Update global metrics
  update-metrics
  let current-max-stress max [stress-level] of humans
  if current-max-stress > max-stress-overall [
    set max-stress-overall current-max-stress
  ]

  ;; Generate new tasks periodically (batch replenishment)
  if ticks mod 50 = 0 and count tasks < initial-tasks [
    generate-tasks
  ]

  ;; Stop if no tasks remain
  if not any? tasks [
    stop
  ]

  tick
end

;; ========================================================================
;; STRESS DYNAMICS
;; [v5 CHANGE] Implements bounded growth with proportional decay:
;;   σ(t+1) = σ(t) + γ·w(t)·[1 - σ(t)/100] - δ·σ(t)/100
;; where γ = 0.1, δ = 0.5
;; Stress is bounded in [0, 100] by construction:
;;   - Growth term γ·w·(1 - σ/100) → 0 as σ → 100 (saturation)
;;   - Decay term δ·σ/100 → 0 as σ → 0 (natural floor)
;; Steady state: σ* = 100·γ·w / (γ·w + δ)
;; ========================================================================

to update-human-state
  ;; Bounded stress accumulation with proportional decay
  let gamma 0.1    ;; stress accumulation rate
  let delta 0.5    ;; stress decay rate

  ;; Normalized stress for bounded dynamics (σ on [0,1] internally)
  let sigma-norm stress-level / 100

  ;; Bounded growth: slows as stress approaches ceiling
  let stress-growth gamma * workload * (1 - sigma-norm)

  ;; Proportional decay: faster recovery at higher stress
  let stress-decay delta * sigma-norm

  ;; Update (convert back to 0-100 scale)
  set stress-level stress-level + (stress-growth - stress-decay) * 100

  ;; Enforce bounds
  set stress-level max list 0 (min list 100 stress-level)

  ;; [v5 CHANGE] Stress does NOT permanently degrade expertise.
  ;; Stress effect is applied temporarily via work-rate in work-on-task.

  ;; Color based on stress
  set color scale-color blue stress-level 100 0
end

;; ========================================================================
;; ROBOT STATE
;; ========================================================================

to update-robot-state
  ;; Battery drain
  set battery-level battery-level - 0.1
  if battery-level < 20 [
    set color red
  ]

  ;; Recharge if very low
  if battery-level < 10 [
    set battery-level 100
    ;; Release current task when recharging
    if assigned-task != nobody [
      ask assigned-task [set assigned-to nobody]
      set assigned-task nobody
    ]
  ]
end

;; ========================================================================
;; TASK FINDING
;; [v5 CHANGE] Autonomy now affects robot behavior:
;;   - High autonomy: robot can take tasks independently regardless of difficulty
;;   - Low autonomy: robot only takes tasks within capability (like humans)
;;   - Moderate autonomy: probabilistic — P(take difficult task) = autonomy/100
;; ========================================================================

to find-task
  let available-tasks tasks with [assigned-to = nobody]
  if any? available-tasks [
    let my-task min-one-of available-tasks [distance myself]
    let can-do-task false

    ;; Check if capable of task
    ask my-task [
      if [breed] of myself = humans [
        ;; Humans take tasks within expertise
        if difficulty <= [expertise] of myself [
          set can-do-task true
        ]
      ]
      if [breed] of myself = robots [
        ;; [v5 CHANGE] Autonomy affects task-taking
        let my-autonomy [autonomy-level] of myself
        let my-capability [capability] of myself

        ifelse difficulty <= my-capability [
          ;; Within capability — always take it
          set can-do-task true
        ] [
          ;; Beyond capability — autonomy determines willingness
          ;; High autonomy robots attempt difficult tasks independently
          if random 100 < my-autonomy [
            set can-do-task true
          ]
        ]
      ]
    ]

    if can-do-task [
      ;; Assign the task
      set assigned-task my-task
      ask my-task [
        set assigned-to myself
      ]
      face my-task

      ;; Update workload for humans
      if breed = humans [
        set workload workload + ([difficulty] of my-task / 10)
      ]
    ]
  ]
end

;; ========================================================================
;; WORK ON TASK
;; [v5 CHANGE] Work rate equation matches paper:
;;   Humans: ω = ε/50 if σ < 70, ω = 0.8·ε/50 if σ ≥ 70
;;   Robots: ω = ψ/50 (with battery penalty below 30)
;; Stress threshold for work rate reduction is 70 (matching paper)
;; Expertise is NOT permanently degraded — only work rate is affected
;; ========================================================================

to work-on-task
  if assigned-task != nobody [
    ;; Check if task still exists
    if not is-task? assigned-task [
      set assigned-task nobody
      if breed = humans [
        set workload max list 0 (workload - 5)
      ]
      stop
    ]

    ;; Move toward task
    face assigned-task
    fd 0.5

    ;; Work on task if close enough
    if distance assigned-task < 1 [
      let work-rate 1

      ;; Calculate work rate based on agent type
      if breed = humans [
        ;; [v5 CHANGE] Paper equation: ω = ε/50, with 0.8 multiplier above stress 70
        set work-rate expertise / 50
        if stress-level > 70 [
          set work-rate work-rate * 0.8
        ]
      ]
      if breed = robots [
        set work-rate capability / 50
        if battery-level < 30 [
          set work-rate work-rate * 0.7
        ]
      ]

      ;; Reduce task time
      ask assigned-task [
        set time-remaining time-remaining - work-rate
      ]

      ;; Robot communication
      if breed = robots [
        if random 100 < communication-frequency [
          communicate-with-humans
        ]
      ]
    ]
  ]
end

;; ========================================================================
;; COLLABORATION
;; ========================================================================

to handle-collaboration
  ask tasks with [requires-collaboration and assigned-to != nobody] [
    let task-self self
    let worker assigned-to

    ;; Find potential collaborator
    let collaborators (turtle-set humans robots) with [
      assigned-task = nobody and self != worker
    ]

    if any? collaborators [
      let collaborator min-one-of collaborators [distance task-self]
      ask collaborator [
        set assigned-task task-self

        ;; Update workload for human collaborators
        if breed = humans [
          set workload workload + ([difficulty] of task-self / 20)
        ]
      ]

      ;; Collaboration bonus - work goes faster
      set time-remaining time-remaining - 2

      ;; Update trust through collaboration
      if [breed] of worker = humans and [breed] of collaborator = robots [
        ask worker [
          set trust-in-robots min list 100 (trust-in-robots + 2)
        ]
      ]
      if [breed] of worker = robots and [breed] of collaborator = humans [
        ask collaborator [
          set trust-in-robots min list 100 (trust-in-robots + 2)
        ]
      ]

      set communication-events communication-events + 1
    ]
  ]
end

;; ========================================================================
;; ROBOT COMMUNICATION
;; ========================================================================

to communicate-with-humans
  let nearby-humans humans in-radius 5
  if any? nearby-humans [
    ask nearby-humans [
      ;; Transparency affects trust
      let trust-increase [transparency] of myself * 0.01
      set trust-in-robots min list 100 (trust-in-robots + trust-increase)
    ]
    set communication-events communication-events + 1
  ]
end

;; ========================================================================
;; TRUST DYNAMICS
;; [v5 CHANGE] Implements paper's Kalman-filter-inspired update:
;;   θ(t+1) = θ(t) + K·[ρ_observed - θ(t)]
;; where K = 0.01 (constant gain)
;; ρ_observed = mean reliability of nearby robots (within radius 10)
;; This produces convergence toward observed reliability level,
;; not a fixed drift relative to 50.
;; ========================================================================

to update-trust-dynamics
  ask humans [
    ;; Kalman-filter-inspired trust update
    let nearby-robots robots in-radius 10
    if any? nearby-robots [
      let observed-performance mean [reliability] of nearby-robots
      let K 0.01  ;; constant gain (learning rate)

      ;; Trust converges toward observed performance
      ;; θ(t+1) = θ(t) + K·[ρ_observed - θ(t)]
      set trust-in-robots trust-in-robots + K * (observed-performance - trust-in-robots)

      ;; Enforce bounds [0, 100]
      set trust-in-robots max list 0 (min list 100 trust-in-robots)
    ]

    ;; Low trust label
    ifelse trust-in-robots < 30 [
      set label "Low Trust"
    ] [
      set label ""
    ]
  ]
end

;; ========================================================================
;; TASK COMPLETION
;; [v5 CHANGE] Human success probability now depends on expertise/difficulty:
;;   P(success) = min(1, expertise / difficulty) × 100
;; Robot success probability = reliability (unchanged)
;; Trust asymmetry on success/failure preserved: +1 success, -5 failure
;; ========================================================================

to complete-task
  let success-probability 50
  let task-agent assigned-to
  let task-diff difficulty

  if task-agent != nobody [
    ask task-agent [
      if breed = humans [
        ;; [v5 CHANGE] P(success) = min(100, expertise / difficulty × 100)
        ;; Matches paper: P(success) = min(1, ε/d)
        ifelse task-diff > 0 [
          set success-probability min list 100 (expertise / task-diff * 100)
        ] [
          set success-probability 100
        ]
      ]
      if breed = robots [
        set success-probability reliability
      ]
    ]

    ;; Determine success/failure
    ifelse random 100 < success-probability [
      ;; Success
      set total-tasks-completed total-tasks-completed + 1

      ;; Trust update on success (asymmetric: +1)
      if [breed] of task-agent = robots [
        ask humans in-radius 10 [
          set trust-in-robots min list 100 (trust-in-robots + 1)
        ]
      ]
    ] [
      ;; Failure
      set task-failure-rate task-failure-rate + 1

      ;; Trust update on failure (asymmetric: -5)
      ;; Consistent with Salem et al. (2015): failures erode trust
      ;; more than successes build it
      if [breed] of task-agent = robots [
        ask humans in-radius 10 [
          set trust-in-robots max list 0 (trust-in-robots - 5)
        ]
      ]
    ]

    ;; Release agent from task
    ask task-agent [
      if breed = humans [
        set workload max list 0 (workload - task-diff / 10)
      ]
      set assigned-task nobody
    ]
  ]

  die
end

;; ========================================================================
;; METRICS
;; ========================================================================

to update-metrics
  if any? humans [
    set average-trust mean [trust-in-robots] of humans
  ]

  ;; Team efficiency: proportion of agents actively working
  let active-agents (count humans with [assigned-task != nobody] +
                     count robots with [assigned-task != nobody])
  let total-agents (count humans + count robots)

  if total-agents > 0 [
    set team-efficiency (active-agents / total-agents) * 100
  ]
end

;; ========================================================================
;; REPORTERS
;; ========================================================================

to-report get-robot-utilization
  if any? robots [
    report (count robots with [assigned-task != nobody] / count robots) * 100
  ]
  report 0
end

to-report get-collaboration-rate
  let collab-tasks count tasks with [requires-collaboration]
  if count tasks > 0 [
    report (collab-tasks / count tasks) * 100
  ]
  report 0
end

to-report get-average-stress
  report mean [stress-level] of humans
end

to-report get-task-success-rate
  let total-attempts total-tasks-completed + task-failure-rate
  if total-attempts > 0 [
    report (total-tasks-completed / total-attempts) * 100
  ]
  report 0
end

to-report get-task-failure-rate
  let total-attempts total-tasks-completed + task-failure-rate
  if total-attempts > 0 [
    report 100 * task-failure-rate / total-attempts
  ]
  report 0
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
41
29
104
62
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
119
27
182
60
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
176
187
209
num-humans
num-humans
1
5
3.0
1
1
NIL
HORIZONTAL

SLIDER
14
218
186
251
num-robots
num-robots
1
5
3.0
1
1
NIL
HORIZONTAL

SLIDER
15
260
187
293
initial-trust
initial-trust
0
100
70.0
1
1
NIL
HORIZONTAL

SLIDER
17
377
189
410
robot-reliability
robot-reliability
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
15
135
187
168
initial-tasks
initial-tasks
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
16
448
188
481
robot-autonomy
robot-autonomy
0
100
90.0
1
1
NIL
HORIZONTAL

SLIDER
17
412
189
445
robot-transparency
robot-transparency
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
13
485
192
518
robot-comm-frequency
robot-comm-frequency
0
100
40.0
1
1
NIL
HORIZONTAL

SLIDER
17
339
189
372
collaboration-rate
collaboration-rate
0
100
82.0
1
1
NIL
HORIZONTAL

MONITOR
678
18
822
63
Tasks Completion Rate
word round(get-task-success-rate) \"%\"
2
1
11

PLOT
889
253
1089
403
Robot Utilization
time
get-robot-utilization
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -5298144 true "" "plot get-robot-utilization"

SLIDER
14
94
186
127
max-ticks
max-ticks
0
2000
2000.0
10
1
NIL
HORIZONTAL

PLOT
668
253
868
403
Average Trust
time
average-trust
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -15040220 true "" "plot average-trust"

PLOT
670
79
870
229
Team Efficiency
time
team-efficiency
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot team-efficiency"

PLOT
913
88
1113
238
Average Stress
time
stress-level
0.0
1000.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -8053223 true "plot mean [stress-level] of humans" "plot mean [stress-level] of humans"

MONITOR
838
17
956
62
Collaboration Rate
word round (get-collaboration-rate) \"%\"
2
1
11

MONITOR
682
429
795
474
Tasks Completed
(word total-tasks-completed \"/\" (total-tasks-completed + task-failure-rate))
0
1
11

MONITOR
974
17
1091
62
Collab tasks
(word count tasks with [requires-collaboration] \"/\" count tasks)
0
1
11

MONITOR
821
429
962
474
NIL
communication-events
0
1
11

MONITOR
990
430
1094
475
Tasks Failed
task-failure-rate
2
1
11

MONITOR
682
490
794
535
Task Failure Rate
(word round (get-task-failure-rate) \"%\")
0
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="All Scenarios Comparison" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1000"/>
    <metric>average-trust</metric>
    <metric>total-tasks-completed</metric>
    <metric>team-efficiency</metric>
    <metric>get-average-stress</metric>
    <metric>get-task-success-rate</metric>
    <metric>communication-events</metric>
    <metric>get-collaboration-rate</metric>
    <metric>get-robot-utilization</metric>
    <runMetricsCondition>ticks mod 100 = 0</runMetricsCondition>
    <enumeratedValueSet variable="initial-tasks">
      <value value="30"/>
      <value value="30"/>
      <value value="60"/>
      <value value="30"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-reliability">
      <value value="90"/>
      <value value="90"/>
      <value value="90"/>
      <value value="80"/>
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-autonomy">
      <value value="70"/>
      <value value="70"/>
      <value value="30"/>
      <value value="80"/>
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-transparency">
      <value value="50"/>
      <value value="80"/>
      <value value="50"/>
      <value value="70"/>
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-comm-frequency">
      <value value="50"/>
      <value value="70"/>
      <value value="50"/>
      <value value="50"/>
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collaboration-rate">
      <value value="50"/>
      <value value="60"/>
      <value value="80"/>
      <value value="80"/>
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Sweep_Reliability" repetitions="50" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>average-trust</metric>
    <metric>total-tasks-completed</metric>
    <metric>team-efficiency</metric>
    <metric>get-average-stress</metric>
    <metric>get-task-success-rate</metric>
    <metric>communication-events</metric>
    <metric>get-robot-utilization</metric>
    <runMetricsCondition>ticks = 2000</runMetricsCondition>
    <steppedValueSet variable="robot-reliability" first="30" step="5" last="100"/>
    <enumeratedValueSet variable="num-humans">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-robots">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-tasks">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-trust">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-autonomy">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-transparency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-comm-frequency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collaboration-rate">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Sweep_InitialTrust" repetitions="50" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>average-trust</metric>
    <metric>total-tasks-completed</metric>
    <metric>team-efficiency</metric>
    <metric>get-average-stress</metric>
    <metric>get-task-success-rate</metric>
    <metric>communication-events</metric>
    <metric>get-robot-utilization</metric>
    <runMetricsCondition>ticks = 2000</runMetricsCondition>
    <steppedValueSet variable="initial-trust" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="num-humans">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-robots">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-tasks">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-reliability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-autonomy">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-transparency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-comm-frequency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collaboration-rate">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Sweep_Transparency" repetitions="50" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>average-trust</metric>
    <metric>total-tasks-completed</metric>
    <metric>team-efficiency</metric>
    <metric>get-average-stress</metric>
    <metric>get-task-success-rate</metric>
    <metric>communication-events</metric>
    <metric>get-robot-utilization</metric>
    <runMetricsCondition>ticks = 2000</runMetricsCondition>
    <steppedValueSet variable="robot-transparency" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="num-humans">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-robots">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-tasks">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-trust">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-reliability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-autonomy">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-comm-frequency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collaboration-rate">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Sweep_CommFrequency" repetitions="50" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>average-trust</metric>
    <metric>total-tasks-completed</metric>
    <metric>team-efficiency</metric>
    <metric>get-average-stress</metric>
    <metric>get-task-success-rate</metric>
    <metric>communication-events</metric>
    <metric>get-robot-utilization</metric>
    <runMetricsCondition>ticks = 2000</runMetricsCondition>
    <steppedValueSet variable="robot-comm-frequency" first="0" step="10" last="100"/>
    <enumeratedValueSet variable="num-humans">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-robots">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-tasks">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-trust">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-reliability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-autonomy">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-transparency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collaboration-rate">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Sweep_TeamSize" repetitions="50" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>average-trust</metric>
    <metric>total-tasks-completed</metric>
    <metric>team-efficiency</metric>
    <metric>get-average-stress</metric>
    <metric>get-task-success-rate</metric>
    <metric>communication-events</metric>
    <metric>get-robot-utilization</metric>
    <runMetricsCondition>ticks = 2000</runMetricsCondition>
    <steppedValueSet variable="num-humans" first="1" step="1" last="5"/>
    <steppedValueSet variable="num-robots" first="1" step="1" last="5"/>
    <enumeratedValueSet variable="initial-tasks">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-trust">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-reliability">
      <value value="90"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-autonomy">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-transparency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-comm-frequency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collaboration-rate">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Sweep_Reliability_x_Transparency" repetitions="50" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="2000"/>
    <metric>average-trust</metric>
    <metric>total-tasks-completed</metric>
    <metric>team-efficiency</metric>
    <metric>get-average-stress</metric>
    <metric>get-task-success-rate</metric>
    <metric>communication-events</metric>
    <metric>get-robot-utilization</metric>
    <runMetricsCondition>ticks = 2000</runMetricsCondition>
    <steppedValueSet variable="robot-reliability" first="40" step="15" last="100"/>
    <steppedValueSet variable="robot-transparency" first="10" step="20" last="90"/>
    <enumeratedValueSet variable="num-humans">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-robots">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-tasks">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-trust">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-autonomy">
      <value value="70"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="robot-comm-frequency">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collaboration-rate">
      <value value="50"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
