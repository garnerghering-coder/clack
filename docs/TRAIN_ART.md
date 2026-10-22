# Train pictures: how each one is drawn

The detailed side views (`apps/web/src/components/trains/`) show a real train in its real livery. Accuracy is the
point (owner, 2026-10-22): a picture that's roughly right is wrong. Every model follows these steps, and nothing is
shown to the owner until step 5 passes.

## 1. Sources first

- At least one **side-on photo** of the train in its **current** livery (owner-supplied, the operator's own, or
  Wikimedia Commons), plus a 3/4 photo for the front. Note each one's source and date in the drawing script.
- Real dimensions: car lengths, body height, axle spacing, wheel diameter (Wikipedia sv/no/en, järnväg.net).
- If a feature can't be seen in any source (a pantograph's car, roof equipment, a door's marking), it isn't drawn.

## 2. Measure, don't eyeball

- Read the side photo's reference points: the nose tip (x), the roof line and the underside of the body (y), and the
  scale in px per metre (from a known length, e.g. a door or the car).
- Read every feature off the photo as coordinates and record them in the script: doors (left, right, top, bottom),
  door windows, window groups and their pane count, the nose outline, roof equipment, and every livery edge.
- Express positions in metres from the nose tip (x) and as a fraction of body height from the roof (y), so the
  drawing is to scale.

## 3. Draw what's there, nothing else

- **Livery edges are drawn as the train has them.** Straight where the paint is straight (most are: two or three
  straight segments with a slight round at a knee), a curve only where the photo shows one. No outline strokes along
  a colour edge unless the train has a painted line there.
- No invented details: no extra chins, stripes, boxes or roof parts. No lettering or operator logos (trademarks);
  the operator's icon sits beside the picture.
- Every model also gets an unpainted version (same drawing, livery off) for an operator whose livery we don't know.

## 4. Style

- Side view facing right: the cab car whole, a sliver of the next. Body gradient light-to-cool, windows dark glass
  in black frames, doors as outlines with their window, bogies and wheels with a lighter rim so they read on dark.
- To scale: 1 m = 40 drawing units.

## 5. Check before showing

- `node scripts/trains/overlay.mjs <drawing.svg> <photo> <out.png> --photo=tipX,roofY,baseY
  --drawing=tipX,roofY,baseY --mpx=<px/m> --mu=40` lays the drawing over the photo, half transparent.
- Every door, window group, the nose and each livery edge must sit on the real one. Fix and re-run until they do.
- Then look at it in the app (light and dark) at its real size.

## Files

- `scripts/trains/<model>.py`: the drawing, with the measured numbers and their sources. Prints the SVG.
- `scripts/trains/build_tsx.py <model> <Component>`: turns it into `apps/web/src/components/trains/<Component>.tsx`.
- `apps/web/src/components/trains/TrainPicture.tsx`: which train types have a drawing, and which operators' liveries.

## Lessons (X3, 2026-10-22)

The first X3 went to the owner three times before it was right: the nose was a guessed curve, the body twice as tall
as the real proportions, the yellow edge a curve with an outline instead of the photo's straight lines, the door and
window heights eyeballed, roof equipment invented. Each was caught by the owner, not by us. Measuring from the
photo and the overlay check (steps 2 and 5) catch all of these.
