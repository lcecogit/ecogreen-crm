/** Room and item catalogue for the visual inventory builder.
 *
 *  Volumes are the standard UK removals-industry estimates in cubic feet —
 *  the same figures a surveyor works from. They are measurements, not prices:
 *  unlike the rate card they are safe defaults rather than provisional
 *  business values. Check them against your own loading experience and adjust;
 *  they are the single biggest driver of quote accuracy.
 *
 *  `crewMinutes` is handling time per unit for one mover: carry, wrap, load.
 *  It drives crew sizing, not price directly. */

export type HandlingClass =
  | "standard"
  | "heavy"
  | "fine_art"
  | "piano"
  | "it_equipment"
  | "laboratory"
  | "medical";

/** Anything not `standard` routes the quote to manual pricing. A confident
 *  automatic price on a grand piano or a lab centrifuge is how a business
 *  discovers it under-quoted after the van has left. */
export const SPECIALIST_CLASSES: readonly HandlingClass[] = [
  "fine_art",
  "piano",
  "it_equipment",
  "laboratory",
  "medical",
];

export function isSpecialist(handling: HandlingClass): boolean {
  return SPECIALIST_CLASSES.includes(handling);
}

export interface Room {
  readonly slug: string;
  readonly name: string;
  readonly icon: string;
  readonly sortOrder: number;
}

export interface CatalogueItem {
  readonly slug: string;
  readonly name: string;
  readonly roomSlug: string;
  readonly icon: string;
  readonly volumeFt3: number;
  readonly crewMinutes: number;
  readonly isFragile: boolean;
  readonly requiresDismantle: boolean;
  readonly handling: HandlingClass;
}

export const ROOMS: readonly Room[] = [
  { slug: "living_room", name: "Living room", icon: "sofa", sortOrder: 1 },
  { slug: "dining_room", name: "Dining room", icon: "dining-table", sortOrder: 2 },
  { slug: "kitchen", name: "Kitchen", icon: "kitchen", sortOrder: 3 },
  { slug: "bedroom", name: "Bedroom", icon: "bed", sortOrder: 4 },
  { slug: "nursery", name: "Nursery", icon: "cot", sortOrder: 5 },
  { slug: "bathroom", name: "Bathroom", icon: "bath", sortOrder: 6 },
  { slug: "study", name: "Study / home office", icon: "desk", sortOrder: 7 },
  { slug: "garage", name: "Garage / shed", icon: "garage", sortOrder: 8 },
  { slug: "garden", name: "Garden", icon: "plant", sortOrder: 9 },
  { slug: "loft", name: "Loft / storage", icon: "boxes", sortOrder: 10 },
  { slug: "office", name: "Commercial office", icon: "office", sortOrder: 11 },
  { slug: "specialist", name: "Specialist items", icon: "shield", sortOrder: 12 },
];

const item = (
  slug: string,
  name: string,
  roomSlug: string,
  icon: string,
  volumeFt3: number,
  crewMinutes: number,
  extra: Partial<Pick<CatalogueItem, "isFragile" | "requiresDismantle" | "handling">> = {},
): CatalogueItem => ({
  slug,
  name,
  roomSlug,
  icon,
  volumeFt3,
  crewMinutes,
  isFragile: extra.isFragile ?? false,
  requiresDismantle: extra.requiresDismantle ?? false,
  handling: extra.handling ?? "standard",
});

export const ITEMS: readonly CatalogueItem[] = [
  // Living room
  item("sofa_2", "Sofa, 2-seater", "living_room", "sofa", 20, 12),
  item("sofa_3", "Sofa, 3-seater", "living_room", "sofa", 25, 15),
  item("sofa_corner", "Corner sofa", "living_room", "sofa", 45, 25, { requiresDismantle: true }),
  item("armchair", "Armchair", "living_room", "armchair", 12, 8),
  item("coffee_table", "Coffee table", "living_room", "table", 8, 5),
  item("tv_55", "Television, up to 55\"", "living_room", "tv", 8, 8, { isFragile: true }),
  item("tv_75", "Television, over 55\"", "living_room", "tv", 14, 12, { isFragile: true }),
  item("bookcase", "Bookcase", "living_room", "bookcase", 20, 12, { requiresDismantle: true }),
  item("rug_large", "Rug, large", "living_room", "rug", 6, 5),
  item("floor_lamp", "Floor lamp", "living_room", "lamp", 5, 4),
  // Dining room
  item("dining_table_4", "Dining table, seats 4", "dining_room", "dining-table", 20, 14, { requiresDismantle: true }),
  item("dining_table_8", "Dining table, seats 6-8", "dining_room", "dining-table", 32, 20, { requiresDismantle: true }),
  item("dining_chair", "Dining chair", "dining_room", "chair", 6, 3),
  item("sideboard", "Sideboard", "dining_room", "sideboard", 25, 15),
  item("display_cabinet", "Display cabinet", "dining_room", "cabinet", 28, 18, { isFragile: true }),
  // Kitchen
  item("fridge_freezer", "Fridge freezer", "kitchen", "fridge", 30, 20, { handling: "heavy" }),
  item("under_counter_fridge", "Under-counter fridge", "kitchen", "fridge", 12, 10),
  item("washing_machine", "Washing machine", "kitchen", "washer", 12, 15, { handling: "heavy" }),
  item("dishwasher", "Dishwasher", "kitchen", "dishwasher", 12, 12, { handling: "heavy" }),
  item("cooker", "Cooker / range", "kitchen", "cooker", 20, 18, { handling: "heavy" }),
  item("microwave", "Microwave", "kitchen", "microwave", 4, 3),
  item("kitchen_box", "Kitchen box, packed", "kitchen", "box", 4, 2, { isFragile: true }),
  // Bedroom
  item("bed_single", "Bed, single", "bedroom", "bed", 20, 14, { requiresDismantle: true }),
  item("bed_double", "Bed, double", "bedroom", "bed", 30, 18, { requiresDismantle: true }),
  item("bed_king", "Bed, king or super king", "bedroom", "bed", 40, 22, { requiresDismantle: true }),
  item("mattress_double", "Mattress, double", "bedroom", "mattress", 18, 10),
  item("wardrobe_single", "Wardrobe, single", "bedroom", "wardrobe", 30, 18, { requiresDismantle: true }),
  item("wardrobe_double", "Wardrobe, double", "bedroom", "wardrobe", 40, 25, { requiresDismantle: true }),
  item("chest_drawers", "Chest of drawers", "bedroom", "drawers", 18, 12),
  item("bedside_table", "Bedside table", "bedroom", "table", 6, 4),
  item("mirror_large", "Mirror, large", "bedroom", "mirror", 5, 6, { isFragile: true }),
  // Nursery
  item("cot", "Cot / cot bed", "nursery", "cot", 18, 12, { requiresDismantle: true }),
  item("changing_table", "Changing table", "nursery", "table", 12, 8),
  item("pushchair", "Pushchair", "nursery", "pushchair", 8, 4),
  // Bathroom
  item("bathroom_cabinet", "Bathroom cabinet", "bathroom", "cabinet", 8, 6),
  item("bathroom_box", "Bathroom box, packed", "bathroom", "box", 4, 2),
  // Study
  item("desk", "Desk", "study", "desk", 20, 14, { requiresDismantle: true }),
  item("office_chair", "Office chair", "study", "chair", 10, 5),
  item("filing_cabinet", "Filing cabinet", "study", "cabinet", 14, 12, { handling: "heavy" }),
  item("desktop_computer", "Desktop computer", "study", "computer", 6, 6, { isFragile: true }),
  item("printer", "Printer", "study", "printer", 6, 5, { isFragile: true }),
  // Garage and garden
  item("bicycle", "Bicycle", "garage", "bicycle", 12, 6),
  item("lawnmower", "Lawnmower", "garage", "mower", 12, 8),
  item("tool_chest", "Tool chest", "garage", "toolbox", 14, 12, { handling: "heavy" }),
  item("workbench", "Workbench", "garage", "workbench", 25, 18, { handling: "heavy" }),
  item("bbq", "Barbecue", "garden", "bbq", 15, 10),
  item("garden_table_set", "Garden table and chairs", "garden", "dining-table", 30, 18),
  item("plant_pot_large", "Plant pot, large", "garden", "plant", 8, 6, { handling: "heavy" }),
  // Boxes and general
  item("box_small", "Box, standard (small)", "loft", "box", 2, 1),
  item("box_large", "Box, double-walled (large)", "loft", "box", 4, 2),
  item("wardrobe_box", "Wardrobe box", "loft", "wardrobe-box", 12, 4),
  item("suitcase", "Suitcase", "loft", "suitcase", 4, 2),
  item("storage_crate", "Storage crate", "loft", "crate", 5, 2),
  // Commercial office
  item("office_desk", "Office desk", "office", "desk", 22, 15, { requiresDismantle: true }),
  item("office_pedestal", "Desk pedestal", "office", "drawers", 8, 6),
  item("meeting_table", "Meeting table", "office", "dining-table", 40, 25, { requiresDismantle: true }),
  item("office_storage_unit", "Office storage unit", "office", "cabinet", 25, 16),
  item("server_rack", "Server rack", "office", "server", 35, 45, { handling: "it_equipment", isFragile: true }),
  item("photocopier", "Photocopier", "office", "printer", 30, 35, { handling: "heavy" }),
  // Specialist — every one of these forces manual pricing
  item("piano_upright", "Piano, upright", "specialist", "piano", 45, 60, { handling: "piano" }),
  item("piano_grand", "Piano, grand", "specialist", "piano", 80, 120, { handling: "piano", requiresDismantle: true }),
  item("artwork_framed", "Artwork, framed", "specialist", "art", 6, 20, { handling: "fine_art", isFragile: true }),
  item("sculpture", "Sculpture", "specialist", "art", 15, 30, { handling: "fine_art", isFragile: true }),
  item("safe", "Safe", "specialist", "safe", 20, 45, { handling: "heavy" }),
  item("lab_equipment", "Laboratory equipment", "specialist", "flask", 20, 40, { handling: "laboratory", isFragile: true }),
  item("medical_equipment", "Medical equipment", "specialist", "medical", 25, 40, { handling: "medical", isFragile: true }),
  item("antique_furniture", "Antique furniture", "specialist", "antique", 25, 30, { handling: "fine_art", isFragile: true }),
];

const ITEM_INDEX = new Map(ITEMS.map((entry) => [entry.slug, entry] as const));

export function findItem(slug: string): CatalogueItem | undefined {
  return ITEM_INDEX.get(slug);
}

export function itemsForRoom(roomSlug: string): readonly CatalogueItem[] {
  return ITEMS.filter((entry) => entry.roomSlug === roomSlug);
}
