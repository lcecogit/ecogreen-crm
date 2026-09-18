import assert from "node:assert/strict";
import { test } from "node:test";

import { ITEMS, ROOMS, findItem, isSpecialist, itemsForRoom } from "../src/domain/inventory/catalogue";
import { USABLE_VAN_FT3, recommendedCrewSize, summariseInventory } from "../src/domain/inventory/volume";

test("the catalogue is internally consistent", () => {
  const roomSlugs = new Set(ROOMS.map((room) => room.slug));
  const seen = new Set<string>();
  for (const item of ITEMS) {
    assert.ok(roomSlugs.has(item.roomSlug), `${item.slug} references unknown room ${item.roomSlug}`);
    assert.ok(!seen.has(item.slug), `duplicate item slug ${item.slug}`);
    seen.add(item.slug);
    assert.ok(item.volumeFt3 > 0, `${item.slug} has no volume`);
    assert.ok(item.crewMinutes > 0, `${item.slug} has no handling time`);
    assert.ok(item.name.length > 0 && item.icon.length > 0);
  }
  assert.ok(ITEMS.length >= 50, "the builder needs a catalogue worth using");
});

test("every room has at least one item, so no room opens empty", () => {
  for (const room of ROOMS) {
    assert.ok(itemsForRoom(room.slug).length > 0, `${room.slug} has no items`);
  }
});

test("volume totals in both units, with van loads shown so customers see the consequence", () => {
  const summary = summariseInventory([
    { itemSlug: "sofa_3", quantity: 1 }, // 25
    { itemSlug: "bed_double", quantity: 2 }, // 60
    { itemSlug: "box_large", quantity: 20 }, // 80
  ]);
  assert.equal(summary.volumeFt3, 165);
  assert.equal(summary.itemCount, 23);
  assert.equal(summary.volumeM3, 4.67);
  assert.equal(summary.estimatedVanLoads, 1);

  const big = summariseInventory([{ itemSlug: "box_large", quantity: 200 }]); // 800 ft³
  assert.equal(big.estimatedVanLoads, Math.ceil(800 / USABLE_VAN_FT3));
});

test("a custom item is priced on its declared volume, never silently dropped", () => {
  const summary = summariseInventory([
    { itemSlug: "custom:hot_tub", quantity: 1, customName: "Hot tub", customVolumeFt3: 90 },
  ]);
  assert.equal(summary.volumeFt3, 90);
  assert.equal(summary.itemCount, 1);
  assert.deepEqual(summary.unknownSlugs, []);
});

test("an unrecognised item with no volume is reported rather than ignored", () => {
  const summary = summariseInventory([{ itemSlug: "mystery", quantity: 3 }]);
  assert.deepEqual(summary.unknownSlugs, ["mystery"]);
  assert.equal(summary.volumeFt3, 0);
});

test("specialist items are surfaced so the quote routes to a human", () => {
  const summary = summariseInventory([
    { itemSlug: "sofa_3", quantity: 1 },
    { itemSlug: "piano_grand", quantity: 1 },
  ]);
  assert.ok(summary.hasSpecialist);
  assert.ok(summary.handlingClasses.includes("piano"));
});

test("fragile and dismantle counts drive the job sheet", () => {
  const summary = summariseInventory([
    { itemSlug: "tv_75", quantity: 2 },
    { itemSlug: "wardrobe_double", quantity: 3 },
  ]);
  assert.equal(summary.fragileCount, 2);
  assert.equal(summary.dismantleCount, 3);
});

test("zero and negative quantities never contribute", () => {
  const summary = summariseInventory([
    { itemSlug: "sofa_3", quantity: 0 },
    { itemSlug: "bed_double", quantity: -2 },
  ]);
  assert.equal(summary.volumeFt3, 0);
  assert.equal(summary.estimatedVanLoads, 0);
});

test("crew sizing never returns a single mover", () => {
  assert.equal(recommendedCrewSize(0), 2);
  assert.equal(recommendedCrewSize(120), 2);
  assert.equal(recommendedCrewSize(900), 3);
  assert.equal(recommendedCrewSize(100_000), 8, "and is capped at a realistic crew");
});

test("every specialist class is recognised as specialist", () => {
  for (const item of ITEMS) {
    if (item.handling === "standard" || item.handling === "heavy") {
      assert.ok(!isSpecialist(item.handling), `${item.slug} should not force manual pricing`);
    } else {
      assert.ok(isSpecialist(item.handling), `${item.slug} must force manual pricing`);
    }
  }
});

test("findItem resolves by slug", () => {
  assert.equal(findItem("piano_grand")?.handling, "piano");
  assert.equal(findItem("nope"), undefined);
});
