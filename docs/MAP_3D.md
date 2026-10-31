# 3D map: references and assumptions

What the 3D campus is based on, and what is a guess. Fix anything wrong here first, then in `data/campus_3d.json`.

## Sources

| What | Source |
| --- | --- |
| Footprints, floor counts, roads, water, pitches | OpenStreetMap extract `data/osm/monash_malaysia.osm` (© OpenStreetMap contributors, ODbL) |
| Building names, what is in each building, cafeteria, main entrance | Official campus map: https://www.monash.edu.my/__data/assets/image/0009/518724/MUM-campus-map.png (linked from https://www.monash.edu.my/about/maps-and-transport) |
| Facade style, main gate | Wikimedia Commons photos: "Cmglee Sunway Monash University.jpg" (CC BY-SA) and "Monash University Malaysia (221208) 01.jpg" |

Photos are only used as reference. None are copied into the project.

## Buildings (from the official map index)

| Building | What's in it | Notes for 3D |
| --- | --- | --- |
| Building 2 | Arts and Social Sciences, Pharmacy, Facilities Management, Plenary Theatre | 7 floors. East side of the main gate |
| Building 3 | Medicine and Health Sciences, Health and Wellness Centre, Lepak Place, Student Hub | West side of the main gate. Blue glass stair towers |
| Building 4 | School of Science | North-west |
| Building 5 / 5A | Engineering, IT, Auditorium 1, Surau | 5A has 8 floors |
| Building 6 | School of Business, Auditorium 2, **Cafeteria**, Maybank, Multi-faith Centre, Surau | Curved block on the east side |
| Building 7 | Library and Learning Commons, The Hive | Curved, low |
| Building 9 | Computer labs, IT Service Desk, MMDAC | Rock climbing wall nearby |
| Link Deck | Idea Link, Mind Link, Oasis | Raised 2-floor bridge between B5 and B6 |
| Monash Sports Centre | Student lounge, badminton courts, dance studios, gym, MUSA/MUPA offices | Green-roofed hall beside the main road |

## Landmarks

- **Main entrance (front gate):** on the main road on the south side, between Building 3 and Building 2, opposite the SunU-Monash BRT station and the BRT car park. A glass skybridge links B3 and B2 above the gate. Below it is a flat white canopy with the "MONASH University" sign, a guardhouse with boom gates, flagpoles, hedges and palms. The BRT line runs overhead on blue pillars. The pavement outside is red hexagon paving.
- **Canteen:** the official map lists the Cafeteria in Building 6 and labels it in the courtyard between Building 9 and Building 6. Assumption: a ground-floor food court in B6 opening onto that courtyard, with outdoor seating under shade.
- Multipurpose courts (MPC1, MPC2) and the Western car park are east of the Sports Centre.

## Look (stylised low-poly)

- Walls: warm beige/sand concrete, with darker beige floor bands.
- Windows: horizontal ribbon windows with a pale green glass tint, set in recessed bays.
- Base: dark charcoal stone on the ground floor and the stair towers.
- Stair/lift towers: tall glass strips (dark teal) with a stone frame. The Monash crest sits near the top of the tower by the gate.
- Bridges: glass skybridges with a light steel frame.
- Roofs: flat, light grey, with a thin overhanging edge and rooftop plant (AC units, tanks).
- Planting: palms, broad tropical trees, low hedges in red/green.

## Assumptions to check

1. The canteen is in B6, facing the B9/B6 courtyard.
2. Floor counts missing from OSM (B3, B4, B5, B7, Sports Centre) are guesses: B3 6, B4 6, B5 6, B7 3, Sports Centre 2.
3. One style for all teaching buildings, with small colour changes. Building 3 gets the blue glass towers from the map.
4. Rooms inside buildings are placeholders, as in `campus.json`.
5. Building 9's ground floor is open: an open passage on columns that people walk through, near the library (from the team). In `campus_3d.json`, `"open_ground_floor": "through"` makes a whole ground floor open; `true`, a side (`"north"`) or a list of sides makes a covered walkway along those sides with rooms behind (4 m deep, a guess).
