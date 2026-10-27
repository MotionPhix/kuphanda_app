subjects = [
  { slug: "biology-msce", name: "Biology", level: "MSCE", icon: "🧬", blurb: "MSCE Biology — cells, genetics, ecology, human systems." },
  { slug: "chemistry-msce", name: "Chemistry", level: "MSCE", icon: "⚗️", blurb: "MSCE Chemistry — reactions, moles, organic chemistry." },
  { slug: "mathematics-msce", name: "Mathematics", level: "MSCE", icon: "📐", blurb: "MSCE Mathematics — algebra, geometry, calculus, statistics." },
  { slug: "physics-msce", name: "Physics", level: "MSCE", icon: "🔭", blurb: "MSCE Physics — mechanics, electricity, waves, modern physics." },
];

// ---------- Topics ----------

topics = [
  // Biology
  { id: "bio-genetics", subjectSlug: "biology-msce", name: "Genetics", order: 1, blurb: "Inheritance, DNA, variation. Highest-yield MSCE Paper 2 topic." },
  { id: "bio-cell", subjectSlug: "biology-msce", name: "Cell biology", order: 2, blurb: "Cell structure, transport, division. Foundational for everything else." },
  { id: "bio-ecology", subjectSlug: "biology-msce", name: "Ecology", order: 3, blurb: "Ecosystems, energy flow, human impact on the environment." },
  { id: "bio-human", subjectSlug: "biology-msce", name: "Human systems", order: 4, blurb: "Digestion, circulation, respiration, excretion, reproduction." },

  // Chemistry
  { id: "chem-atoms", subjectSlug: "chemistry-msce", name: "Atomic structure & bonding", order: 1, blurb: "Atoms, electron configuration, ionic and covalent bonds." },
  { id: "chem-moles", subjectSlug: "chemistry-msce", name: "The mole & stoichiometry", order: 2, blurb: "Moles, formulae, balancing equations, yield." },
  { id: "chem-reactions", subjectSlug: "chemistry-msce", name: "Reactions & energetics", order: 3, blurb: "Acids/bases, redox, rates, energy changes." },
  { id: "chem-organic", subjectSlug: "chemistry-msce", name: "Organic chemistry", order: 4, blurb: "Hydrocarbons, alcohols, carboxylic acids, polymers." },

  // Mathematics
  { id: "math-algebra", subjectSlug: "mathematics-msce", name: "Algebra", order: 1, blurb: "Equations, inequalities, quadratics, sequences." },
  { id: "math-geometry", subjectSlug: "mathematics-msce", name: "Geometry & trigonometry", order: 2, blurb: "Angles, similarity, circles, sine/cosine rules." },
  { id: "math-calculus", subjectSlug: "mathematics-msce", name: "Introductory calculus", order: 3, blurb: "Differentiation and integration of polynomials." },
  { id: "math-stats", subjectSlug: "mathematics-msce", name: "Statistics & probability", order: 4, blurb: "Measures of centre/spread, probability rules." },

  // Physics
  { id: "phys-mechanics", subjectSlug: "physics-msce", name: "Mechanics", order: 1, blurb: "Kinematics, Newton's laws, momentum, energy." },
  { id: "phys-electricity", subjectSlug: "physics-msce", name: "Electricity & magnetism", order: 2, blurb: "Circuits, Ohm's law, magnetic fields, induction." },
  { id: "phys-waves", subjectSlug: "physics-msce", name: "Waves & optics", order: 3, blurb: "Wave properties, sound, reflection, refraction." },
];

// ---------- Subtopics ----------

subtopics = [
  // ==== Biology: Genetics ====
  {
    id: "bio-gen-mendelian",
    topicId: "bio-genetics",
    name: "Mendelian inheritance",
    order: 1,
    learningObjectives: [
      "Define allele, gene, genotype, phenotype, homozygous, heterozygous.",
      "State Mendel's law of segregation.",
      "Predict F1 and F2 ratios for a monohybrid cross.",
    ],
    difficulty: 2,
    estimatedMinutes: 25,
    prerequisites: [],
    resourceRefs: ["msce-biology-2023-paper2"],
    keyIdeas: [
      "Every gene has two alleles, one from each parent.",
      "Dominant allele masks the recessive in the heterozygote.",
      "3:1 phenotypic ratio in the F2 of a monohybrid cross.",
    ],
    commonMistakes: [
      "Confusing genotype with phenotype.",
      "Writing alleles in lowercase for a dominant trait.",
    ],
  },
  {
    id: "bio-gen-punnett",
    topicId: "bio-genetics",
    name: "Punnett squares",
    order: 2,
    learningObjectives: [
      "Draw a 2x2 Punnett square for a monohybrid cross.",
      "Read genotypic and phenotypic ratios from the square.",
      "Apply Punnett squares to test crosses.",
    ],
    difficulty: 2,
    estimatedMinutes: 20,
    prerequisites: ["bio-gen-mendelian"],
    resourceRefs: ["msce-biology-2023-paper2"],
    keyIdeas: [
      "Rows = alleles from one parent, columns = the other.",
      "Each cell = one possible offspring genotype.",
    ],
    commonMistakes: [
      "Filling the square with phenotypes instead of genotypes.",
      "Forgetting to combine both alleles in each cell.",
    ],
  },
  {
    id: "bio-gen-dihybrid",
    topicId: "bio-genetics",
    name: "Dihybrid crosses",
    order: 3,
    learningObjectives: [
      "Set up a 4x4 dihybrid Punnett square.",
      "Predict the 9:3:3:1 F2 ratio.",
      "State Mendel's law of independent assortment.",
    ],
    difficulty: 4,
    estimatedMinutes: 35,
    prerequisites: ["bio-gen-punnett"],
    resourceRefs: [],
    keyIdeas: [
      "Independent assortment produces four gamete types: AB, Ab, aB, ab.",
      "9:3:3:1 is the signature ratio of a dihybrid F2.",
    ],
    commonMistakes: [
      "Only producing two gamete types instead of four.",
      "Mixing up the 9:3:3:1 phenotypes.",
    ],
  },
  {
    id: "bio-gen-dna",
    topicId: "bio-genetics",
    name: "DNA structure & replication",
    order: 4,
    learningObjectives: [
      "Describe the double helix and base pairing rules.",
      "Outline semi-conservative replication.",
      "Distinguish DNA from RNA.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["bio-gen-mendelian"],
    resourceRefs: [],
    keyIdeas: [
      "A pairs with T, G pairs with C.",
      "Replication produces two daughter molecules, each with one parent strand.",
    ],
    commonMistakes: [
      "Pairing A with G or C with T.",
      "Calling replication 'conservative'.",
    ],
  },
  {
    id: "bio-gen-variation",
    topicId: "bio-genetics",
    name: "Variation & mutation",
    order: 5,
    learningObjectives: [
      "Distinguish continuous from discontinuous variation.",
      "Describe causes and effects of gene mutations.",
      "Give examples of environmental variation.",
    ],
    difficulty: 3,
    estimatedMinutes: 25,
    prerequisites: ["bio-gen-dna"],
    resourceRefs: [],
    keyIdeas: [
      "Continuous variation: height, mass. Discontinuous: blood group.",
      "Mutations are random changes in DNA sequence.",
    ],
    commonMistakes: [
      "Claiming all mutations are harmful.",
      "Confusing genetic with environmental variation.",
    ],
  },

  // ==== Biology: Cell biology ====
  {
    id: "bio-cell-structure",
    topicId: "bio-cell",
    name: "Cell structure",
    order: 1,
    learningObjectives: [
      "Label the parts of animal and plant cells.",
      "State the function of nucleus, mitochondria, chloroplasts, cell wall, vacuole.",
      "Compare prokaryotic and eukaryotic cells.",
    ],
    difficulty: 2,
    estimatedMinutes: 25,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "Mitochondria = respiration; chloroplasts = photosynthesis.",
      "Only plant cells have cell walls, chloroplasts, and large vacuoles.",
    ],
    commonMistakes: [
      "Saying animal cells have chloroplasts.",
      "Confusing cell wall with cell membrane.",
    ],
  },
  {
    id: "bio-cell-transport",
    topicId: "bio-cell",
    name: "Membrane transport",
    order: 2,
    learningObjectives: [
      "Define diffusion, osmosis, and active transport.",
      "Explain the role of concentration gradients.",
      "Interpret experiments on osmosis in potato cells.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["bio-cell-structure"],
    resourceRefs: [],
    keyIdeas: [
      "Osmosis: water moves from dilute to concentrated solution across a partially permeable membrane.",
      "Active transport uses ATP and moves against the gradient.",
    ],
    commonMistakes: [
      "Confusing osmosis with diffusion of solutes.",
      "Forgetting that active transport needs energy.",
    ],
  },
  {
    id: "bio-cell-division",
    topicId: "bio-cell",
    name: "Mitosis & meiosis",
    order: 3,
    learningObjectives: [
      "Describe the stages of mitosis.",
      "Contrast mitosis with meiosis.",
      "Link meiosis to genetic variation.",
    ],
    difficulty: 4,
    estimatedMinutes: 35,
    prerequisites: ["bio-cell-structure"],
    resourceRefs: [],
    keyIdeas: [
      "Mitosis: identical daughter cells for growth/repair.",
      "Meiosis: 4 haploid gametes with genetic variation.",
    ],
    commonMistakes: [
      "Mixing up chromosome numbers between mitosis and meiosis.",
      "Forgetting crossing over as a source of variation.",
    ],
  },

  // ==== Biology: Ecology ====
  {
    id: "bio-eco-ecosystems",
    topicId: "bio-ecology",
    name: "Ecosystems & energy flow",
    order: 1,
    learningObjectives: [
      "Define ecosystem, community, population, habitat.",
      "Draw food chains and food webs with correct arrows.",
      "Explain the 10% rule of energy transfer.",
    ],
    difficulty: 2,
    estimatedMinutes: 25,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "Arrows in food chains point from prey to predator (direction of energy flow).",
      "Only ~10% of energy is passed to the next trophic level.",
    ],
    commonMistakes: [
      "Drawing food chain arrows the wrong way.",
      "Confusing producer with primary consumer.",
    ],
  },
  {
    id: "bio-eco-cycles",
    topicId: "bio-ecology",
    name: "Carbon & nitrogen cycles",
    order: 2,
    learningObjectives: [
      "Describe the carbon cycle including respiration, photosynthesis, combustion.",
      "Describe the nitrogen cycle including fixation, nitrification, denitrification.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["bio-eco-ecosystems"],
    resourceRefs: [],
    keyIdeas: [
      "Decomposers return carbon and nitrogen to the ecosystem.",
      "Nitrogen-fixing bacteria convert N₂ to ammonia.",
    ],
    commonMistakes: [
      "Forgetting combustion as a carbon flux.",
      "Confusing nitrification with nitrogen fixation.",
    ],
  },

  // ==== Biology: Human systems ====
  {
    id: "bio-hum-digestion",
    topicId: "bio-human",
    name: "Digestion",
    order: 1,
    learningObjectives: [
      "Trace food through the alimentary canal.",
      "Match enzymes to substrates (amylase, protease, lipase).",
      "Explain absorption in the small intestine.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "Villi provide a large surface area for absorption.",
      "Bile emulsifies fats but is not an enzyme.",
    ],
    commonMistakes: [
      "Calling bile an enzyme.",
      "Confusing the roles of the small and large intestines.",
    ],
  },
  {
    id: "bio-hum-circulation",
    topicId: "bio-human",
    name: "Circulation",
    order: 2,
    learningObjectives: [
      "Describe the double circulation of blood.",
      "Compare arteries, veins, and capillaries.",
      "Explain the role of the heart chambers and valves.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "Left side of the heart pumps oxygenated blood at higher pressure.",
      "Arteries → capillaries → veins.",
    ],
    commonMistakes: [
      "Swapping oxygenated and deoxygenated sides of the heart.",
      "Confusing pulmonary and systemic circulation.",
    ],
  },

  // ==== Chemistry: Atomic structure & bonding ====
  {
    id: "chem-atom-structure",
    topicId: "chem-atoms",
    name: "Atomic structure",
    order: 1,
    learningObjectives: [
      "State the relative mass and charge of proton, neutron, electron.",
      "Define atomic number and mass number.",
      "Write electron configurations for the first 20 elements.",
    ],
    difficulty: 2,
    estimatedMinutes: 25,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "Atomic number = number of protons = element identity.",
      "Electron shells fill 2, 8, 8, ...",
    ],
    commonMistakes: [
      "Confusing atomic number with mass number.",
      "Placing more than 8 electrons in shells 2 or 3 for MSCE-level.",
    ],
  },
  {
    id: "chem-bonding-ionic",
    topicId: "chem-atoms",
    name: "Ionic bonding",
    order: 2,
    learningObjectives: [
      "Explain how ions form by electron transfer.",
      "Write formulae for common ionic compounds.",
      "Relate structure to properties (high melting point, conducts when molten).",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["chem-atom-structure"],
    resourceRefs: [],
    keyIdeas: [
      "Metals lose electrons; non-metals gain electrons.",
      "Giant ionic lattices are held together by strong electrostatic forces.",
    ],
    commonMistakes: [
      "Saying ionic compounds conduct as solids.",
      "Getting charges backwards on cations vs anions.",
    ],
  },
  {
    id: "chem-bonding-covalent",
    topicId: "chem-atoms",
    name: "Covalent bonding",
    order: 3,
    learningObjectives: [
      "Draw dot-and-cross diagrams for simple molecules.",
      "Contrast simple molecular with giant covalent structures.",
      "Explain properties in terms of intermolecular forces.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["chem-atom-structure"],
    resourceRefs: [],
    keyIdeas: [
      "Sharing electron pairs creates a covalent bond.",
      "Diamond and graphite are both giant covalent — same element, different properties.",
    ],
    commonMistakes: [
      "Confusing covalent bond strength with weak intermolecular forces.",
      "Forgetting graphite conducts electricity.",
    ],
  },

  // ==== Chemistry: Moles ====
  {
    id: "chem-mole-concept",
    topicId: "chem-moles",
    name: "The mole concept",
    order: 1,
    learningObjectives: [
      "Define the mole and Avogadro's constant.",
      "Calculate moles from mass and Mr.",
      "Convert between moles, mass, and number of particles.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["chem-atom-structure"],
    resourceRefs: [],
    keyIdeas: [
      "1 mole = 6.02 × 10²³ particles = Mr grams.",
      "moles = mass ÷ Mr.",
    ],
    commonMistakes: [
      "Using atomic number instead of Mr.",
      "Mixing units (g vs kg).",
    ],
  },
  {
    id: "chem-stoichiometry",
    topicId: "chem-moles",
    name: "Stoichiometry & yield",
    order: 2,
    learningObjectives: [
      "Balance chemical equations.",
      "Use mole ratios to calculate reacting masses.",
      "Calculate percentage yield and percentage purity.",
    ],
    difficulty: 4,
    estimatedMinutes: 40,
    prerequisites: ["chem-mole-concept"],
    resourceRefs: [],
    keyIdeas: [
      "Balanced equations give the mole ratio between reactants and products.",
      "% yield = (actual ÷ theoretical) × 100.",
    ],
    commonMistakes: [
      "Skipping the balancing step.",
      "Confusing % yield with % purity.",
    ],
  },

  // ==== Chemistry: Reactions ====
  {
    id: "chem-acids-bases",
    topicId: "chem-reactions",
    name: "Acids, bases & salts",
    order: 1,
    learningObjectives: [
      "Define acid, base, alkali in terms of H⁺ and OH⁻.",
      "Write neutralisation equations.",
      "Describe preparation of soluble and insoluble salts.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["chem-bonding-ionic"],
    resourceRefs: [],
    keyIdeas: [
      "Neutralisation: H⁺ + OH⁻ → H₂O.",
      "Titration prepares soluble salts of alkali + acid.",
    ],
    commonMistakes: [
      "Confusing strong/concentrated and weak/dilute.",
      "Forgetting to test with indicator during titration.",
    ],
  },
  {
    id: "chem-redox",
    topicId: "chem-reactions",
    name: "Redox reactions",
    order: 2,
    learningObjectives: [
      "Define oxidation and reduction in terms of electrons and oxidation numbers.",
      "Identify oxidising and reducing agents.",
    ],
    difficulty: 4,
    estimatedMinutes: 35,
    prerequisites: ["chem-atom-structure"],
    resourceRefs: [],
    keyIdeas: [
      "OIL RIG: Oxidation Is Loss, Reduction Is Gain (of electrons).",
      "Oxidising agent is itself reduced.",
    ],
    commonMistakes: [
      "Swapping oxidising and reducing agents.",
      "Forgetting oxidation number rules for O and H.",
    ],
  },

  // ==== Chemistry: Organic ====
  {
    id: "chem-org-hydrocarbons",
    topicId: "chem-organic",
    name: "Hydrocarbons",
    order: 1,
    learningObjectives: [
      "Distinguish alkanes from alkenes.",
      "Name the first six alkanes and alkenes.",
      "Describe combustion and addition reactions.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["chem-bonding-covalent"],
    resourceRefs: [],
    keyIdeas: [
      "Alkanes are saturated (C-C); alkenes are unsaturated (C=C).",
      "Bromine water: orange → colourless indicates an alkene.",
    ],
    commonMistakes: [
      "Reversing the bromine water test result.",
      "Miscounting carbons when naming.",
    ],
  },

  // ==== Mathematics: Algebra ====
  {
    id: "math-alg-linear",
    topicId: "math-algebra",
    name: "Linear equations & inequalities",
    order: 1,
    learningObjectives: [
      "Solve linear equations in one variable.",
      "Solve and represent linear inequalities on a number line.",
      "Solve simultaneous linear equations by substitution and elimination.",
    ],
    difficulty: 2,
    estimatedMinutes: 30,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "Do the same operation to both sides.",
      "Flip the inequality sign when multiplying/dividing by a negative.",
    ],
    commonMistakes: [
      "Forgetting to flip the inequality sign.",
      "Sign errors when subtracting across the equals sign.",
    ],
  },
  {
    id: "math-alg-quadratics",
    topicId: "math-algebra",
    name: "Quadratic equations",
    order: 2,
    learningObjectives: [
      "Solve quadratics by factorising, completing the square, and the formula.",
      "Sketch a quadratic and identify roots, vertex, and axis of symmetry.",
    ],
    difficulty: 4,
    estimatedMinutes: 40,
    prerequisites: ["math-alg-linear"],
    resourceRefs: [],
    keyIdeas: [
      "x = (-b ± √(b² - 4ac)) / 2a.",
      "Discriminant b² - 4ac tells you how many real roots exist.",
    ],
    commonMistakes: [
      "Missing the ± in the quadratic formula.",
      "Sign slips inside the discriminant.",
    ],
  },
  {
    id: "math-alg-sequences",
    topicId: "math-algebra",
    name: "Sequences & series",
    order: 3,
    learningObjectives: [
      "Identify arithmetic and geometric sequences.",
      "Use nth term and sum formulae.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["math-alg-linear"],
    resourceRefs: [],
    keyIdeas: [
      "AP: aₙ = a + (n-1)d.",
      "GP: aₙ = ar^(n-1).",
    ],
    commonMistakes: [
      "Using n instead of (n-1) in the AP formula.",
      "Confusing common difference d with common ratio r.",
    ],
  },

  // ==== Mathematics: Geometry ====
  {
    id: "math-geom-trig",
    topicId: "math-geometry",
    name: "Trigonometry basics",
    order: 1,
    learningObjectives: [
      "Use SOHCAHTOA in right-angled triangles.",
      "Apply Pythagoras' theorem.",
      "Solve problems involving angles of elevation and depression.",
    ],
    difficulty: 3,
    estimatedMinutes: 35,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "sin = opp/hyp, cos = adj/hyp, tan = opp/adj.",
      "a² + b² = c² for right-angled triangles only.",
    ],
    commonMistakes: [
      "Applying Pythagoras to non-right triangles.",
      "Mixing up opposite and adjacent sides.",
    ],
  },
  {
    id: "math-geom-sine-cosine",
    topicId: "math-geometry",
    name: "Sine & cosine rules",
    order: 2,
    learningObjectives: [
      "Use the sine rule to find sides and angles.",
      "Use the cosine rule to find sides and angles.",
      "Find the area of a triangle using ½ab sin C.",
    ],
    difficulty: 4,
    estimatedMinutes: 40,
    prerequisites: ["math-geom-trig"],
    resourceRefs: [],
    keyIdeas: [
      "Sine rule: a/sin A = b/sin B = c/sin C.",
      "Cosine rule: a² = b² + c² - 2bc cos A.",
    ],
    commonMistakes: [
      "Using sine rule when only three sides are known.",
      "Sign slips when rearranging the cosine rule for an angle.",
    ],
  },
  {
    id: "math-geom-circles",
    topicId: "math-geometry",
    name: "Circle theorems",
    order: 3,
    learningObjectives: [
      "State and apply the main circle theorems (angle at centre, cyclic quadrilateral, alternate segment).",
    ],
    difficulty: 4,
    estimatedMinutes: 35,
    prerequisites: ["math-geom-trig"],
    resourceRefs: [],
    keyIdeas: [
      "Angle at centre = 2 × angle at circumference on the same arc.",
      "Opposite angles of a cyclic quadrilateral sum to 180°.",
    ],
    commonMistakes: [
      "Applying the alternate segment theorem to the wrong angle.",
      "Forgetting that the angle in a semicircle is 90°.",
    ],
  },

  // ==== Mathematics: Calculus ====
  {
    id: "math-calc-diff",
    topicId: "math-calculus",
    name: "Differentiation of polynomials",
    order: 1,
    learningObjectives: [
      "Differentiate axⁿ using the power rule.",
      "Find gradients of curves at a point.",
      "Locate stationary points and classify them.",
    ],
    difficulty: 4,
    estimatedMinutes: 40,
    prerequisites: ["math-alg-quadratics"],
    resourceRefs: [],
    keyIdeas: [
      "d/dx(xⁿ) = nxⁿ⁻¹.",
      "At a stationary point, dy/dx = 0.",
    ],
    commonMistakes: [
      "Forgetting to bring the power down.",
      "Confusing dy/dx = 0 (stationary) with y = 0 (root).",
    ],
  },
  {
    id: "math-calc-int",
    topicId: "math-calculus",
    name: "Integration of polynomials",
    order: 2,
    learningObjectives: [
      "Integrate axⁿ (n ≠ -1).",
      "Evaluate definite integrals.",
      "Interpret the definite integral as area under a curve.",
    ],
    difficulty: 4,
    estimatedMinutes: 40,
    prerequisites: ["math-calc-diff"],
    resourceRefs: [],
    keyIdeas: [
      "∫xⁿ dx = xⁿ⁺¹/(n+1) + C.",
      "Definite integrals: F(b) - F(a).",
    ],
    commonMistakes: [
      "Forgetting the constant of integration for indefinite integrals.",
      "Adding 1 to the wrong exponent.",
    ],
  },

  // ==== Mathematics: Statistics ====
  {
    id: "math-stats-centre",
    topicId: "math-stats",
    name: "Measures of centre & spread",
    order: 1,
    learningObjectives: [
      "Calculate mean, median, and mode for grouped and ungrouped data.",
      "Calculate range and (simple) standard deviation.",
    ],
    difficulty: 2,
    estimatedMinutes: 30,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "For grouped data use midpoints.",
      "Median = middle value after ordering.",
    ],
    commonMistakes: [
      "Forgetting to sort before finding the median.",
      "Using class boundaries instead of midpoints for the mean.",
    ],
  },
  {
    id: "math-stats-prob",
    topicId: "math-stats",
    name: "Probability",
    order: 2,
    learningObjectives: [
      "Apply the addition and multiplication rules.",
      "Use tree diagrams for combined events.",
      "Distinguish independent from mutually exclusive events.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "P(A and B) = P(A) × P(B) if independent.",
      "P(A or B) = P(A) + P(B) - P(A and B).",
    ],
    commonMistakes: [
      "Adding probabilities of non-mutually-exclusive events without subtracting the overlap.",
      "Confusing independence with mutual exclusivity.",
    ],
  },

  // ==== Physics: Mechanics ====
  {
    id: "phys-mech-kinematics",
    topicId: "phys-mechanics",
    name: "Kinematics",
    order: 1,
    learningObjectives: [
      "Distinguish distance/displacement and speed/velocity.",
      "Use the SUVAT equations for uniform acceleration.",
      "Interpret displacement–time and velocity–time graphs.",
    ],
    difficulty: 3,
    estimatedMinutes: 35,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "v = u + at; s = ut + ½at².",
      "Area under a v-t graph = displacement.",
    ],
    commonMistakes: [
      "Using SUVAT when acceleration is not uniform.",
      "Confusing displacement with distance travelled.",
    ],
  },
  {
    id: "phys-mech-newton",
    topicId: "phys-mechanics",
    name: "Newton's laws",
    order: 2,
    learningObjectives: [
      "State all three of Newton's laws.",
      "Apply F = ma to problems.",
      "Analyse action–reaction pairs.",
    ],
    difficulty: 3,
    estimatedMinutes: 35,
    prerequisites: ["phys-mech-kinematics"],
    resourceRefs: [],
    keyIdeas: [
      "Resultant force = mass × acceleration.",
      "Action–reaction pairs act on different bodies.",
    ],
    commonMistakes: [
      "Confusing weight (a force) with mass.",
      "Applying action–reaction to the same object.",
    ],
  },
  {
    id: "phys-mech-momentum",
    topicId: "phys-mechanics",
    name: "Momentum & impulse",
    order: 3,
    learningObjectives: [
      "Calculate momentum p = mv.",
      "Apply conservation of momentum to collisions.",
      "Relate impulse to change in momentum.",
    ],
    difficulty: 4,
    estimatedMinutes: 35,
    prerequisites: ["phys-mech-newton"],
    resourceRefs: [],
    keyIdeas: [
      "Total momentum before = total momentum after (closed system).",
      "Impulse = FΔt = Δp.",
    ],
    commonMistakes: [
      "Forgetting momentum is a vector (direction matters).",
      "Applying conservation of KE to inelastic collisions.",
    ],
  },

  // ==== Physics: Electricity ====
  {
    id: "phys-elec-ohm",
    topicId: "phys-electricity",
    name: "Ohm's law & simple circuits",
    order: 1,
    learningObjectives: [
      "Use V = IR to solve circuit problems.",
      "Calculate series and parallel resistance.",
      "Interpret ammeter and voltmeter readings.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "Ammeter in series, voltmeter in parallel.",
      "Series: R = R₁ + R₂. Parallel: 1/R = 1/R₁ + 1/R₂.",
    ],
    commonMistakes: [
      "Placing an ammeter in parallel (short circuit).",
      "Adding parallel resistances directly.",
    ],
  },
  {
    id: "phys-elec-power",
    topicId: "phys-electricity",
    name: "Electrical power & energy",
    order: 2,
    learningObjectives: [
      "Use P = VI and E = Pt.",
      "Calculate cost of electrical energy in kWh.",
    ],
    difficulty: 2,
    estimatedMinutes: 25,
    prerequisites: ["phys-elec-ohm"],
    resourceRefs: [],
    keyIdeas: [
      "1 kWh = 3.6 × 10⁶ J.",
      "P = I²R = V²/R.",
    ],
    commonMistakes: [
      "Mixing kW and W in bill calculations.",
      "Using time in minutes instead of hours for kWh.",
    ],
  },

  // ==== Physics: Waves ====
  {
    id: "phys-wave-basics",
    topicId: "phys-waves",
    name: "Wave properties",
    order: 1,
    learningObjectives: [
      "Define wavelength, frequency, period, amplitude.",
      "Use v = fλ.",
      "Distinguish transverse and longitudinal waves.",
    ],
    difficulty: 2,
    estimatedMinutes: 25,
    prerequisites: [],
    resourceRefs: [],
    keyIdeas: [
      "v = fλ.",
      "Sound = longitudinal; light = transverse.",
    ],
    commonMistakes: [
      "Confusing period with frequency.",
      "Swapping transverse and longitudinal examples.",
    ],
  },
  {
    id: "phys-wave-optics",
    topicId: "phys-waves",
    name: "Reflection & refraction",
    order: 2,
    learningObjectives: [
      "State the laws of reflection.",
      "Apply Snell's law n₁ sin θ₁ = n₂ sin θ₂.",
      "Explain total internal reflection and critical angle.",
    ],
    difficulty: 3,
    estimatedMinutes: 30,
    prerequisites: ["phys-wave-basics"],
    resourceRefs: [],
    keyIdeas: [
      "Angle of incidence = angle of reflection (measured from the normal).",
      "TIR requires light going from denser → less dense medium above the critical angle.",
    ],
    commonMistakes: [
      "Measuring angles from the surface instead of the normal.",
      "Applying TIR the wrong way (less dense → denser).",
    ],
  },
];

// ---------- Query helpers ----------
const fs = require('fs');
fs.writeFileSync('G:/FlutterApps/kuphanda/tool/curriculum_raw.json', JSON.stringify({subjects, topics, subtopics}, null, 2));
console.log('subjects', subjects.length, 'topics', topics.length, 'subtopics', subtopics.length);
