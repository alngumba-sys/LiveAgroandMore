-- ============================================================
-- Knowledge Base RE-SEED (restores articles wiped by the demo-data cleanup).
-- The knowledge_base table + functions/trigger/RLS still exist — this only
-- re-inserts article rows. Run once in the Supabase SQL editor.
-- 40 articles across agronomy / products / market_prices / services / weather / faq.
-- search_vector is repopulated automatically by the existing trigger.
-- ============================================================

-- Safety: if you ever re-run this file, uncomment the next line first so you
-- don't create duplicate articles (the table has no unique constraint on title):
-- DELETE FROM knowledge_base;

-- ---- Set 1: original 8 sample articles ----
INSERT INTO knowledge_base (title, content, category, tags) VALUES

-- Agronomy
('Maize Stalk Borer Control',
 'The maize stalk borer (Busseola fusca) is the most damaging pest in Uganda. Signs include dead hearts in young plants and frass (sawdust-like droppings) in leaf whorls. Control: Apply Duduthrin or Ampligo insecticide into the whorl at 2-3 week intervals. For biological control, release Cotesia sesamiae parasitoids. Plant early to avoid peak moth populations.',
 'agronomy', ARRAY['maize','pest','stalk borer','insecticide']),

('Tomato Late Blight Management',
 'Late blight (Phytophthora infestans) causes brown lesions on leaves and fruit. It spreads fast in wet, cool weather. Prevention: Use certified disease-free seedlings. Spray Ridomil Gold or Mancozeb every 7-10 days during rainy season. Remove and destroy infected plants immediately. Avoid overhead irrigation.',
 'agronomy', ARRAY['tomatoes','disease','blight','fungicide']),

('Soil Fertility — DAP vs CAN',
 'DAP (Di-Ammonium Phosphate) is best applied at planting — it provides phosphorus for strong root development. Use 50kg per acre. CAN (Calcium Ammonium Nitrate) is a top-dressing fertiliser applied 4-6 weeks after planting to boost leafy growth. Use 50kg per acre. Never mix the two fertilisers before applying.',
 'agronomy', ARRAY['fertiliser','DAP','CAN','soil','nutrients']),

-- Products
('Agro & More Input Products',
 'We stock: Seeds (maize, beans, sorghum, sunflower, vegetables), Fertilisers (DAP, CAN, NPK, Urea), Pesticides (Duduthrin, Ampligo, Ridomil, Mancozeb, Glyphosate), Tools (hoes, sprayers, slashers). All products are certified and sourced from verified suppliers. Contact your nearest Agro & More agent or call our inputs desk to place an order.',
 'products', ARRAY['seeds','fertiliser','pesticides','tools','inputs']),

-- Market prices
('Current Produce Prices',
 'Off-take prices this season (per kg): Maize grain — UGX 800-1,000. Beans — UGX 2,500-3,000. Sorghum — UGX 700-900. Sunflower — UGX 1,200-1,500. Prices vary by quality, moisture content, and market conditions. Call our aggregation officer for the latest prices before harvesting.',
 'market_prices', ARRAY['prices','maize','beans','sorghum','sunflower','market']),

-- Services
('How to Order Inputs from Agro & More',
 'You can order inputs in 3 ways: 1. USSD — Dial *284*31# and select "Order for inputs". Our inputs desk will call you back within minutes. 2. Call — Phone our inputs desk directly. 3. Visit — Walk into any Agro & More agent location. Payment is made on delivery. Bulk orders (5+ bags) qualify for free delivery within 20km.',
 'services', ARRAY['order','delivery','inputs','USSD']),

-- FAQ
('What is the best planting time for maize in Uganda?',
 'In Uganda there are two planting seasons: Season A (March–May) and Season B (August–October). Plant at the onset of rains. For highland areas above 1,500m, Season A is more reliable. Use certified hybrid seed varieties like H614, DK8031, or SEEDCO SC403 for best yields. Space plants 75cm between rows and 25cm within rows.',
 'faq', ARRAY['maize','planting','season','seeds']),

('How do I know if my soil needs lime?',
 'Signs of acidic soil: stunted growth, yellowing leaves, and poor fertiliser response even after applying DAP or CAN. Confirm with a soil pH test — if pH is below 5.5 your soil is acidic. Apply agricultural lime (calcium carbonate) at 1-2 tonnes per acre, worked into the soil 3 months before planting. Agro & More can arrange soil testing through our agronomist.',
 'faq', ARRAY['soil','pH','lime','acidity']);

-- ---- Set 2: v3 (8 articles) ----
INSERT INTO knowledge_base (title, content, category, tags) VALUES

-- ── AGRONOMY ──────────────────────────────────────────────────────────────────

('Drip Irrigation for Smallholder Farmers',
 'Drip irrigation delivers water directly to plant roots, reducing water use by up to 60% compared to flood irrigation and cutting disease risk from wet foliage. Setup: 1. Connect a 200-litre drum or tank elevated at least 1 metre above the ground — gravity provides enough pressure. 2. Lay the main hose along the row, then connect drip emitter lines for each crop row. 3. Punch small holes or use emitter buttons spaced at 30cm intervals for vegetables, 50cm for maize. Cost: A basic kit for a 0.1-acre garden costs about UGX 250,000–400,000 and lasts 5+ seasons. Best for: tomatoes, capsicum, onions, watermelon, and horticultural crops in the dry season. Water your crops in the early morning (6–8am) to reduce evaporation losses.',
 'agronomy', ARRAY['irrigation','drip','water','dry season','vegetables','horticulture']),

('Post-Harvest Maize Storage Using PICS Bags',
 'Aflatoxin contamination from poor storage can cause serious health problems and reduce market value. PICS (Purdue Improved Crop Storage) bags are triple-layered hermetic bags that prevent aflatoxin, weevils, and grain borers without chemicals. How to use: 1. Sun-dry grain until moisture is below 13% — test by biting a grain; it should be hard and click, not soft. 2. Fill the inner bag, twist and tie it tightly, then fill and tie the second inner bag, then the outer jute bag. 3. Store on wooden pallets — never directly on the ground or against walls. 4. Check bags monthly for holes. PICS bags last 4+ seasons if handled carefully. Available at Agro & More outlets. Price: approximately UGX 8,000–12,000 per bag (100 kg capacity).',
 'agronomy', ARRAY['maize','storage','PICS bags','aflatoxin','post-harvest','grain','weevils']),

('Soil pH Testing and Lime Application',
 'Most crops grow best at a soil pH of 5.5–6.5. Acid soils (below 5.5) are common in Uganda especially in high-rainfall areas, and cause nutrient lockup where fertiliser is wasted even when applied. How to test: Buy a simple soil pH kit from Agro & More (UGX 15,000–25,000) or collect soil samples and bring them to our office for testing. Correction: Apply agricultural lime (calcium carbonate) at 1–2 tonnes per acre for moderately acid soils, or Dolomite lime if magnesium is also low. Apply lime at land preparation, at least 2 weeks before planting and before applying fertiliser — lime and fertiliser applied together cancel each other out. One lime application lasts 2–3 seasons. Common crops needing correct pH: beans, maize, groundnuts, and vegetables.',
 'agronomy', ARRAY['soil','pH','lime','acidity','fertility','soil test','dolomite']),

('Tomato Late Blight Management',
 'Late blight (Phytophthora infestans) is the most destructive tomato disease, especially in cool wet conditions. A field can be lost within 3 days in severe cases. Signs: water-soaked dark-green patches on leaves that turn brown rapidly, white fuzzy mould on undersides of leaves in morning, brown rot on fruit. Prevention is the only reliable strategy: 1. Start preventive sprays at transplanting — spray Ridomil Gold (metalaxyl+mancozeb), Equation Pro, or Cabriotop every 7–10 days during rains. 2. Alternate between systemic and contact fungicides to prevent resistance. 3. Plant on ridges or raised beds to improve drainage. 4. Stake plants to keep foliage off the ground. 5. Avoid overhead irrigation. If blight appears, remove and destroy affected leaves and increase spray frequency to every 5 days.',
 'agronomy', ARRAY['tomato','late blight','Phytophthora','Ridomil','fungicide','disease','spray']),

('Starting an Onion Crop in Uganda',
 'Onions are a high-value crop with strong demand in Ugandan markets. Best varieties for Uganda: Red Bombay (60 days, high yield), Jambar F1 (65 days, good storage), and Red Creole (open-pollinated, drought-tolerant). Planting: Raise seedlings in a nursery bed for 5–6 weeks, then transplant at 15cm × 10cm spacing. Soil: Sandy loam to loam with good drainage. Avoid waterlogged areas — onions rot easily. Fertiliser: Apply 5 tonnes of compost/acre at land prep, then CAN (Calcium Ammonium Nitrate) at 50 kg/acre three weeks after transplanting, and again at bulb initiation (when tops begin to fall). Water: Regular moisture is critical in the first 6 weeks; reduce watering 2 weeks before harvest. Harvest when 75% of tops have fallen over. Cure onions in shade for 2 weeks before storing or selling.',
 'agronomy', ARRAY['onion','vegetables','Red Bombay','seedling','transplanting','horticulture']),

-- ── PRODUCTS ─────────────────────────────────────────────────────────────────

('Understanding Fertiliser Labels — NPK Explained',
 'Every fertiliser bag shows three numbers called NPK: Nitrogen (N), Phosphorus (P), and Potassium (K). These are the percentages of each nutrient. Example: DAP (18:46:0) contains 18% Nitrogen and 46% Phosphorus — excellent for root development at planting. CAN (26:0:0) is 26% pure nitrogen — good for vegetative growth and top-dressing leafy crops. NPK 17:17:17 is a balanced fertiliser suited to crops that need all three nutrients equally, like vegetables. Urea (46:0:0) is the highest-nitrogen fertiliser — apply carefully as it burns if placed directly on roots. Common Uganda rule of thumb: apply DAP at planting (phosphorus builds roots), then CAN or Urea at 4–6 weeks (nitrogen drives growth). Always apply fertiliser into moist soil — never into dry ground. Store bags on pallets, off the ground and away from moisture.',
 'products', ARRAY['fertiliser','NPK','DAP','CAN','Urea','nitrogen','phosphorus','potassium']),

-- ── SERVICES ─────────────────────────────────────────────────────────────────

('How to Access Agricultural Loans in Uganda',
 'Several financing options exist for farmers in Uganda. 1. SACCOS (Savings and Credit Cooperatives): The easiest entry point. Join a farmer SACCO in your area, save for 3–6 months, then borrow up to 3× your savings at 1–2% per month. Agro & More can connect you with vetted SACCOs in your district. 2. DFCU Bank Agri-Finance: Offers seasonal crop loans of UGX 1M–50M with flexible repayment tied to harvest. Requires land title or alternative collateral. 3. Uganda Development Bank (UDB): Long-term loans for agribusiness at 12–15% p.a. Minimum loan UGX 10M. Requires a business plan and 2 years of farming records. 4. Opportunity Bank and Finance Trust Bank also offer agri-microloans from UGX 500,000. Documents typically needed: National ID, land documents or tenancy agreement, recent bank statement or mobile money statement, and a simple farm business plan. Agro & More offers free business plan templates — ask any of our staff.',
 'services', ARRAY['loan','credit','SACCO','DFCU','financing','agribusiness','UDB']),

-- ── MARKET PRICES ─────────────────────────────────────────────────────────────

('Groundnut Market Prices and Selling Tips',
 'Groundnut prices in Uganda follow seasonal patterns. Prices are LOWEST at peak harvest (March–April and September–October) when supply floods the market. Prices are HIGHEST in June–July and December–January during the off-season. Typical price ranges at Owino and Nakasero markets: Shelled groundnuts (Grade A) UGX 3,200–5,500 per kg. Groundnut paste (simsim) UGX 6,500–9,000 per kg. Unshelled groundnuts UGX 1,800–3,000 per kg. Tips for better prices: 1. Store properly in a dry, well-ventilated store — groundnuts readily absorb moisture and develop aflatoxin if stored in damp conditions. 2. Grade your produce — sort out damaged, discoloured, and small nuts before selling. 3. Sell to processors (cooking oil factories, paste makers) rather than middlemen — typically 15–20% better price. 4. Join a farmer group or cooperative to aggregate volumes and negotiate better prices. Contact Agro & More for connections to buyers and cooperatives in your area.',
 'market_prices', ARRAY['groundnuts','peanuts','market prices','storage','selling','cooperative','aflatoxin']);

-- ---- Set 3: extra (24 articles) ----
INSERT INTO knowledge_base (title, content, category, tags) VALUES

-- ── AGRONOMY (12 more) ────────────────────────────────────────────────────────

('Fall Armyworm Control in Maize',
 'Fall armyworm (Spodoptera frugiperda) is an invasive pest that can destroy an entire maize field within days. Signs: ragged holes in leaves, frass (droppings) resembling wet sawdust in the whorl, and small caterpillars with an inverted "Y" mark on the head. Control: Act fast — spray Coragen (chlorantraniliprole), Belt (flubendiamide), or Ampligo into the whorl early in the morning or evening. Apply at first sign of damage, repeat after 7 days. Biological option: spray Metarhizium anisopliae fungus. For prevention, plant early and avoid late planting which coincides with peak moth activity.',
 'agronomy', ARRAY['maize','fall armyworm','pest','Coragen','Ampligo','whorl']),

('Banana Xanthomonas Wilt (BXW) Management',
 'Banana Xanthomonas Wilt (BXW) is the most serious banana disease in Uganda. Signs: yellowing and wilting of leaves starting from older leaves, yellow ooze from cut stems, premature ripening of fruit, and rotting of the male bud. There is NO chemical cure. Management: 1. Cut and bury infected plants completely. 2. Remove the male bud using a forked stick — do not use a panga which spreads the disease. 3. Use clean, uninfected planting material. 4. Sterilise all cutting tools with fire or bleach between plants. Early detection and removal of infected plants is the only way to save your plantation.',
 'agronomy', ARRAY['bananas','BXW','Xanthomonas','wilt','disease','management']),

('Coffee Wilt Disease (Fusarium) Control',
 'Coffee Wilt Disease (CWD), caused by Fusarium xylarioides, is the biggest threat to Robusta coffee in Uganda. Signs: sudden yellowing and wilting of branches starting from the top, brown discolouration inside the stem when cut, and rapid death of the tree. Prevention: Plant certified wilt-tolerant varieties like Nyasaland and Clone 12 from NARO/UCDA nurseries. Management: Remove and burn infected trees immediately — do not compost them. Leave the stump in the ground (uprooting spreads spores). Apply Trichoderma bio-fungicide to the surrounding soil. Maintain tree spacing of 3m × 3m for air circulation.',
 'agronomy', ARRAY['coffee','Fusarium','wilt','disease','Robusta','Uganda']),

('Bean Rust and Anthracnose Control',
 'Bean rust (Uromyces appendiculatus) shows as small orange-brown powdery pustules on leaf undersides. Anthracnose (Colletotrichum lindemuthianum) causes dark sunken lesions on pods, stems and leaves — most damaging in cool wet weather. Control for both: Use certified disease-resistant seed varieties. Spray Mancozeb or Comet (pyraclostrobin) every 10-14 days during rainy season. Avoid overhead irrigation. Practice crop rotation — do not plant beans in the same field two seasons in a row. Destroy crop residues after harvest to remove disease sources.',
 'agronomy', ARRAY['beans','rust','anthracnose','disease','Mancozeb','fungicide']),

('Cassava Brown Streak Disease (CBSD) Management',
 'Cassava Brown Streak Disease (CBSD) is spread by whiteflies and infected cuttings. Signs on leaves: yellow-green chlorotic patches along leaf veins. Signs on tubers: brown corky rot inside the tuber even when the outside looks healthy — making the cassava inedible. Prevention: Only use certified clean cuttings from NARO or trusted seed multipliers. Control whiteflies with Actara (thiamethoxam) or Kingcode Elite. Rogue and destroy infected plants early. Plant CBSD-tolerant varieties such as NASE 14, Narocass 1, or Kibandameno. Never replant cuttings from an infected field.',
 'agronomy', ARRAY['cassava','CBSD','whitefly','brown streak','disease','cuttings']),

('Sweet Potato Weevil Management',
 'The sweet potato weevil (Cylas puncticollis) is the most serious sweet potato pest in Uganda. Adult weevils lay eggs in vines and tubers; larvae tunnel through the tuber, causing a black bitter taste that makes it unfit for eating or selling. Control: 1. Use clean, weevil-free planting vines from trusted sources. 2. Plant at the start of the rains when soil moisture is high — dry soil encourages weevils. 3. Mound soil over exposed tubers regularly (earthing up). 4. Harvest promptly when mature — do not leave tubers in the ground. 5. Practice crop rotation — avoid planting sweet potatoes in the same field consecutively. There is no effective chemical cure once weevils are inside the tuber.',
 'agronomy', ARRAY['sweet potato','weevil','Cylas','pest','storage','earthing up']),

('Making and Using Compost on the Farm',
 'Compost improves soil structure, water retention, and provides slow-release nutrients — reducing your need for expensive fertilisers. How to make a compost heap: 1. Choose a shaded spot and build a heap 1.5m wide × 1m tall. 2. Alternate layers: green material (crop residues, banana peels, fresh grass) with brown material (dry leaves, maize stalks, wood ash). 3. Add a thin layer of soil or manure every 30cm to add microorganisms. 4. Keep the heap moist — not wet — and turn it every 2-3 weeks. 5. Compost is ready in 2-3 months when it is dark brown and earthy-smelling. Application: Dig in 2-3 tonnes per acre before planting. Compost works best when combined with small amounts of mineral fertiliser.',
 'agronomy', ARRAY['compost','organic','soil','fertility','manure','nutrients']),

('Intercropping: Growing Two Crops Together',
 'Intercropping means growing two or more crops on the same piece of land at the same time. Common combinations in Uganda: Maize + beans (beans fix nitrogen that feeds the maize), sorghum + cowpeas, and bananas + coffee. Benefits: Better use of land, reduced weed pressure, reduced pest build-up, and income from two crops on the same land. How to intercrop maize and beans: Plant maize at 75cm × 25cm spacing. Plant 2 bean seeds between every two maize plants (45cm apart in the row). Apply DAP fertiliser at planting for both crops. Avoid climbing bean varieties which can smother maize — use bush bean varieties like K20, NABE 4, or Kablanketi.',
 'agronomy', ARRAY['intercropping','maize','beans','mixed farming','land use']),

('Post-Harvest Maize Storage to Prevent Weevils and Aflatoxin',
 'Poor storage destroys up to 30% of the maize harvest in Uganda. Key rules: 1. Dry well — maize must be below 13% moisture content before storing. Test by biting a grain: it should crack sharply, not feel soft. 2. Shell and clean the grain — remove diseased, broken, or discoloured grains. 3. Treat with Actellic Super dust (pirimiphos-methyl + permethrin) at 1 teaspoon per 10kg of grain to kill weevils and storage moths. 4. Store in clean, airtight bags or metal silos in a cool, dry, raised space. 5. Avoid mixing old stock with new grain. 6. Check bags monthly for moisture, weevils, or mold — discard visibly mouldy grain (aflatoxin is invisible and deadly).',
 'agronomy', ARRAY['maize','storage','weevils','aflatoxin','post-harvest','Actellic']),

('Sunflower Growing Guide for Uganda',
 'Sunflower is a drought-tolerant cash crop that thrives in drier areas of Uganda (Acholi, Teso, Lango). It requires 450-650mm of rainfall. Varieties: Sunfola, Record, and Hybrid varieties from NARO. Planting: Prepare land and plant at start of rains. Space 75cm between rows, 30cm within rows. Apply DAP at 50kg per acre at planting. Top-dress with CAN at 50kg per acre at 4 weeks. Pest watch: Sunflower head moth and aphids — spray with Duduthrin if numbers are high. Harvest: When back of head turns yellow-brown and seeds are firm. Cut heads, dry in shade, and thresh. Off-take price: UGX 1,200-1,500 per kg. Contact Agro & More aggregation officer for bulk buying.',
 'agronomy', ARRAY['sunflower','cash crop','drought','planting','Acholi','Teso','oil']),

('Managing Soil Erosion on Sloped Land',
 'Soil erosion strips away the most fertile topsoil and reduces yields over time. Prevention measures for sloped land: 1. Contour farming — plough and plant in rows running across the slope (not up and down). 2. Grass strips — plant narrow strips of Napier grass or vetiver grass across the slope every 10-15 metres to slow water. 3. Mulching — cover soil between crop rows with dry grass or crop residues to break rainfall impact. 4. Terracing — build level terraces on steep slopes (above 15% gradient) to hold water and soil. 5. Minimum tillage — avoid leaving bare soil exposed between planting seasons. 6. Agroforestry — plant trees on boundaries and steep areas to hold soil with their roots.',
 'agronomy', ARRAY['erosion','soil','terracing','contour','mulching','slope','conservation']),

('Tomato Nursery and Transplanting Guide',
 'Raising tomato seedlings in a nursery gives you stronger, more uniform plants and saves seed. Nursery preparation: Fill seedling trays or raised beds with a mix of topsoil, compost, and sand (2:1:1). Sow seeds thinly, cover with a thin layer of soil, and water gently twice daily. Seeds germinate in 5-7 days. After 3-4 weeks (when seedlings have 2-3 true leaves), harden them off by reducing watering for 5 days before transplanting. Transplanting: Water nursery thoroughly 2 hours before lifting seedlings. Transplant in the evening or on a cloudy day to reduce stress. Space plants 60cm between rows, 45cm within rows. Apply DAP (a tablespoon per hole) at planting. Water immediately after transplanting.',
 'agronomy', ARRAY['tomatoes','nursery','transplanting','seedlings','spacing','DAP']),

-- ── PRODUCTS (3 more) ─────────────────────────────────────────────────────────

('Safe Pesticide Handling and Storage',
 'Improper pesticide use is dangerous to your health, your family, and the environment. Safety rules: 1. Always read the label before use — follow the dosage exactly, more is not better and damages crops. 2. Wear protection — rubber gloves, boots, long-sleeved clothing, and a mask when mixing and spraying. 3. Never spray in wind or rain. Spray early morning or late evening when bees are not active. 4. Do not eat, drink, or smoke while handling pesticides. 5. Wash hands, face, and equipment thoroughly after spraying. 6. Store pesticides in original containers in a locked, cool, dry place away from food, children, and animals. 7. Do not dispose of empty containers near water sources — triple-rinse and puncture them. If you feel unwell after spraying, seek medical help immediately.',
 'products', ARRAY['pesticide','safety','storage','handling','PPE','spraying']),

('Choosing the Right Herbicide for Your Farm',
 'Herbicides save weeding labour but must be matched to the crop and weed type. Key herbicides stocked by Agro & More: 1. Glyphosate (Roundup, Weedmaster) — non-selective, kills all plants. Use for land clearing before planting only. Do not spray on growing crops. 2. Atrazine — selective for maize. Applied to soil within 3 days of planting to prevent weed germination. Does not work on established weeds. 3. 2,4-D Amine — selective for broad-leaved weeds in maize and sorghum. Apply at 3-5 weeks after crop emergence. Do not use on beans, vegetables, or near banana/coffee. 4. Stomp (pendimethalin) — pre-emergence herbicide for maize, sunflower, and vegetables. Important: Always calibrate your sprayer before use and wear gloves and boots.',
 'products', ARRAY['herbicide','Glyphosate','Atrazine','2,4-D','weeds','weed control']),

('NPK Fertiliser — When and How to Use It',
 'NPK fertilisers contain three key nutrients: Nitrogen (N) for leaf growth, Phosphorus (P) for roots and flowering, and Potassium (K) for fruit quality and disease resistance. Common NPK blends stocked by Agro & More: NPK 17:17:17 (balanced for vegetables and general use) and NPK 23:23:0 (for crops where extra potassium is not needed). Application guide: For vegetables — apply NPK 17:17:17 at 50-75kg per acre at planting, mixed into the planting hole. For maize — DAP at planting gives better phosphorus; NPK is ideal where soil tests show balanced nutrient need. For tomatoes — apply NPK at transplanting, then switch to CAN top-dressing at fruiting. Always water after applying granular fertiliser to activate it.',
 'products', ARRAY['NPK','fertiliser','nitrogen','phosphorus','potassium','vegetables','nutrients']),

-- ── MARKET PRICES (2 more) ────────────────────────────────────────────────────

('Coffee Cherry and Parchment Prices',
 'Current coffee off-take prices (approximate, subject to world market): Robusta cherry — UGX 1,000-1,400 per kg. Robusta parchment (dried, hulled) — UGX 5,500-7,000 per kg. Arabica parchment (highland areas) — UGX 8,000-11,000 per kg. Quality premiums apply: properly dried coffee (11-12% moisture) fetches 15-20% more than wet or over-dried lots. Agro & More works with certified buyers — contact our aggregation officer for the current week''s price before harvesting and drying. Ensure coffee is fully red (cherry) before picking for maximum price. Do not mix under-ripe green cherries with ripe ones.',
 'market_prices', ARRAY['coffee','Robusta','Arabica','cherry','parchment','prices','Uganda']),

('Sesame (Simsim) and Groundnut Prices',
 'Sesame (simsim) and groundnuts are important cash crops across northern and eastern Uganda. Current approximate off-take prices: Sesame (simsim) — UGX 4,500-6,000 per kg for clean, dry grain (moisture below 9%). Mixed or dirty sesame fetches 30-40% less. Groundnuts (shelled, dry) — UGX 3,500-4,500 per kg. Groundnuts in shell (dry) — UGX 1,800-2,400 per kg. Price tips: Dry well — moisture above 9% causes rejection or heavy discounting. Sort and clean before selling — remove stones, chaff, and shrivelled seeds. Contact Agro & More aggregation officer for the current price and bulk buying schedule in your area.',
 'market_prices', ARRAY['sesame','simsim','groundnuts','prices','northern Uganda','eastern Uganda']),

-- ── SERVICES (2 more) ─────────────────────────────────────────────────────────

('Request a Farm Visit from an Agro & More Agronomist',
 'Agro & More field agronomists can visit your farm to diagnose crop problems, recommend inputs, and advise on best practices. How to request a visit: 1. Dial *284*31# on your phone. 2. Select option 2 — "Talk to an Agronomist". 3. Enter your name, location, and a brief description of your problem (e.g. "My maize leaves are turning yellow"). 4. Our agronomist will call you back within 1-2 hours to schedule a visit. Farm visits are free for registered Agro & More farmers. For urgent crop emergencies (e.g. pest outbreak), mention "URGENT" in your message and we will prioritise your visit.',
 'services', ARRAY['agronomist','farm visit','USSD','field officer','consultation','support']),

('How Agro & More Produce Aggregation Works',
 'Agro & More buys produce from smallholder farmers at fair, pre-agreed prices. How it works: 1. Check the current off-take price by dialling *284*31# → "Sell My Produce", or calling our aggregation officer. 2. Agree on quantity and collection date. 3. Prepare your produce — it must meet quality standards: dry, clean, properly sorted, and free from moisture and foreign matter. 4. Our field officer or truck will collect from an agreed collection point. 5. Payment is made within 24-48 hours by mobile money to your registered number. Minimum quantities: Maize — 500kg. Beans/sorghum — 200kg. Sunflower/sesame — 100kg. Farmers who supply consistently and reliably qualify for advance input financing from next season.',
 'services', ARRAY['aggregation','sell produce','off-take','collection','payment','mobile money']),

-- ── WEATHER (2 more) ──────────────────────────────────────────────────────────

('Preparing Your Farm for Dry Spells',
 'Uganda''s climate is increasingly variable — dry spells within the rainy season are more common. How to protect your crops: 1. Mulching — cover soil around plants with dry grass or crop residues (5-10cm thick) to retain moisture and reduce soil temperature. This can extend a plant''s survival by 2-3 extra weeks without rain. 2. Choose drought-tolerant varieties — maize varieties like DK8031 and Longe 5 perform better under dry conditions than older varieties. 3. Plant on time — crops planted at the right time develop deep roots before dry spells hit. Late-planted crops are most vulnerable. 4. Apply potassium fertiliser (CAN or muriate of potash) — potassium improves drought tolerance. 5. Avoid over-applying nitrogen during dry spells — it stresses plants that cannot take up water.',
 'weather', ARRAY['drought','dry spell','mulching','moisture','climate','resilience']),

('How to Protect Crops During Heavy Rains and Flooding',
 'Prolonged heavy rains can damage or destroy crops through waterlogging, disease spread, and soil erosion. Protective measures: 1. Drainage channels — dig shallow trenches (30cm deep) between crop rows on flat land to channel water away. 2. Raised beds — for vegetables, plant on raised beds 20-30cm above ground level to keep roots out of standing water. 3. Avoid compaction — do not walk on wet soil as it destroys soil structure and worsens waterlogging. 4. Fungal disease prevention — apply Mancozeb or Ridomil Gold preventatively before and during prolonged wet periods, especially on tomatoes, potatoes, and beans. 5. Staking and support — tall crops like tomatoes and beans need staking to prevent lodging (falling over) in heavy rain and wind.',
 'weather', ARRAY['rain','flooding','waterlogging','drainage','raised beds','wet season']),

-- ── FAQ (3 more) ──────────────────────────────────────────────────────────────

('What Are the Signs of Over-Fertilisation?',
 'Applying too much fertiliser, especially nitrogen, can harm your crops and waste money. Signs of over-fertilisation: Leaves turn dark green, then yellow or brown at the tips and edges (leaf scorch). Plants grow very tall and leafy but produce little fruit or grain. In extreme cases, roots are damaged and plants wilt even with adequate water (fertiliser burn). Prevention: Always follow the recommended rate — for most crops, 50kg of DAP and 50kg of CAN per acre is sufficient. Split top-dressing applications — apply half at 4 weeks and half at 8 weeks instead of all at once. Never apply fertiliser to dry soil without immediate irrigation or rain expected within 24 hours. If over-fertilisation has occurred, irrigate heavily to flush excess nutrients from the root zone.',
 'faq', ARRAY['fertiliser','over-fertilisation','leaf scorch','burn','nitrogen','rates']),

('How Do I Store Seeds at Home Between Seasons?',
 'Properly stored seed can last 1-2 seasons without losing germination quality. Rules for home seed storage: 1. Dry thoroughly — seeds must be below 12% moisture content (a handful should feel dry and cool, not cold and damp). 2. Clean — remove broken, shrivelled, or diseased seeds before storage. 3. Use airtight containers — sealed plastic jerricans, glass jars, or metal tins are better than open sacks. Place 2 tablespoons of dry wood ash or dry sand in the bottom to absorb moisture. 4. Add a repellent — a few dried chilli peppers or neem leaves deter storage pests without chemicals. 5. Label clearly — write the variety name and date on the container. 6. Store in a cool, dry, dark place — away from direct sunlight and cooking heat. Check every 4-6 weeks. Note: Hybrid seeds (F1) should not be saved — buy fresh hybrid seed every season.',
 'faq', ARRAY['seeds','storage','seed saving','home storage','germination','hybrid']),

('How Can I Access Farm Inputs on Credit?',
 'Agro & More offers input financing to qualifying farmers so you can access seeds and fertilisers now and pay after harvest. How to qualify: 1. Be a registered Agro & More farmer with at least one full season of purchasing history. 2. Have a confirmed off-take agreement — you commit to selling your produce to Agro & More at harvest. 3. Have a valid national ID and a mobile money account. How to apply: Dial *284*31# → "Order for Inputs" and mention you are interested in credit financing, or speak directly to an Agro & More field officer. Repayment: The value of inputs is deducted from your harvest payment. Interest rates and terms are agreed upfront. Farmers who repay on time qualify for larger credit limits the following season.',
 'faq', ARRAY['credit','financing','inputs','loan','repayment','off-take','registered farmer']);
