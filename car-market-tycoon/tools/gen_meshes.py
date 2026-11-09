"""Generates smooth car body / glass / roof / tarp meshes for every archetype in
src/shared/Modules/VehicleBuilder.luau and writes assets/CarMeshes.obj (units: studs, Y up, front = -Z).

Usage:  python3 tools/gen_meshes.py
Import the OBJ in Roblox Studio (Home -> Import 3D), rename the imported model to "CarMeshes" and
put it into ReplicatedStorage/Assets. The game then uses these meshes instead of the block bodies.
"""
import math, re, random, os, sys

S = 2.8
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = open(os.path.join(ROOT, 'src/shared/Modules/VehicleBuilder.luau'), encoding='utf-8').read()


def parse_archetypes():
    start = SRC.index('VehicleBuilder.Archetypes = {')
    end = SRC.index('-- Helpers ---')
    block = SRC[start:end]
    arch = {}
    for m in re.finditer(r'\n\t(\w+) = \{\n(.*?)\n\t\},', block, re.S):
        name, body = m.group(1), m.group(2)

        def num(k, default=None):
            mm = re.search(r'\b' + k + r' = ([\d.]+)', body)
            return float(mm.group(1)) if mm else default

        def pts(k):
            mm = re.search(r'\b' + k + r' = \{ (.*?) \},\n', body)
            return [tuple(map(float, p.split(','))) for p in re.findall(r'\{ ([\d., ]+?) \}', mm.group(1))]

        a = {k: num(k) for k in ['L', 'W', 'H', 'FO', 'WB', 'D', 'TW', 'Clr', 'WS0', 'WS1', 'R1', 'RW1']}
        a['GH'] = num('GH', 0.8)
        a['Body'] = pts('Body')
        a['Roof'] = pts('Roof')
        a['Flares'] = 'Flares = true' in body
        a['Rear'] = re.search(r'Rear = "(\w+)"', body).group(1)
        bed = re.search(r'Bed = \{ Z0 = ([\d.]+), Z1 = ([\d.]+), Top = ([\d.]+) \}', body)
        a['Bed'] = tuple(map(float, bed.groups())) if bed else None
        arch[name] = a
    return arch


def interp(p, z):
    if z <= p[0][0]:
        return p[0][1]
    for i in range(1, len(p)):
        a, b = p[i - 1], p[i]
        if z <= b[0]:
            span = b[0] - a[0]
            t = (z - a[0]) / span if span > 1e-6 else 1
            return a[1] + (b[1] - a[1]) * t
    return p[-1][1]


def smooth_profile(f, z, r=0.06):
    # light smoothing so sharp profile corners become rounded
    return (f(z - r) + 2 * f(z) + f(z + r)) / 4


class Car:
    def __init__(self, a):
        self.a = a
        a['Roof'][-1] = (a['Roof'][-1][0], interp(a['Body'], a['RW1']))
        self.R = a['D'] / 2
        self.Ra = self.R + 0.07
        self.axles = [a['FO'], a['FO'] + a['WB']]
        L = a['L']
        self.width_pts = [(0, 0.86), (L * 0.06, 0.96), (L * 0.18, 1), (L * 0.84, 1), (L * 0.95, 0.96), (L, 0.88)]

    def body_top(self, z):
        return interp(self.a['Body'], max(0, min(self.a['L'], z)))

    def arch_y(self, z):
        y = 0
        for ax in self.axles:
            dz = abs(z - ax)
            if dz < self.Ra:
                y = max(y, self.R + math.sqrt(self.Ra * self.Ra - dz * dz))
        return y

    def top_adj(self, z):
        ay = self.arch_y(z)
        bt = self.body_top(z)
        if ay > 0:
            return max(bt, ay + (0.09 if self.a['Flares'] else 0.05))
        return bt

    def top_smooth(self, z):
        return smooth_profile(self.top_adj, z, 0.05)

    def cabin_top(self, z):
        a = self.a
        if z <= a['WS1']:
            t = max(0, min(1, (z - a['WS0']) / max(0.01, a['WS1'] - a['WS0'])))
            return self.body_top(a['WS0']) + (a['Roof'][0][1] - self.body_top(a['WS0'])) * t
        return interp(a['Roof'], z)

    def width(self, z):
        base = self.a['W'] * interp(self.width_pts, max(0, min(self.a['L'], z))) / 2
        # wheel "hips": the body swells a little over each wheel (more at the rear)
        bulge = 0
        for i, ax in enumerate(self.axles):
            amount = 0.018 if i == 0 else 0.03
            bulge += amount * math.exp(-((z - ax) / (self.Ra * 1.1)) ** 2)
        return base + bulge

    def side_bottom(self, z):
        a = self.a
        lift = 0.09 * max(0, 1 - z / 0.16) + 0.07 * max(0, 1 - (a['L'] - z) / 0.16)
        ay = self.arch_y(z)
        return max(a['Clr'] + lift, ay) if ay > 0 else a['Clr'] + lift

    def stations(self, z0, z1, base_step=0.12):
        zs = set()
        z = z0
        while z < z1:
            zs.add(round(z, 4))
            z += base_step
        zs.add(z1)
        for ax in self.axles:  # dense around the arches for a round outline
            k = -1.0
            while k <= 1.0001:
                zz = ax + k * self.Ra * 1.02
                if z0 <= zz <= z1:
                    zs.add(round(zz, 4))
                k += 0.08
        for p in self.a['Body'] + self.a['Roof']:
            if z0 <= p[0] <= z1:
                zs.add(round(p[0], 4))
        # dense near both ends so the nose and tail are rounded
        for e in (0.02, 0.05, 0.09):
            for zz in (z0 + e, z1 - e):
                zs.add(round(zz, 4))
        return sorted(zs)

    # --- cross sections (right half, from top centre down; x>=0) ---------------------------
    def body_section(self, z):
        t = self.top_smooth(z)
        b = self.side_bottom(z)
        w = self.width(z)
        h = max(0.05, t - b)
        crown = 0.018
        # rounding at the very nose / tail: shrink the shoulder radius
        return [
            (0.0, t + crown),
            (0.45 * w, t + crown * 0.8),
            (0.78 * w, t + crown * 0.15),
            (0.92 * w, t - 0.025),
            (0.985 * w, t - min(0.09, h * 0.25)),
            (1.0 * w, t - min(0.17, h * 0.4)),
            (0.995 * w, b + h * 0.42),
            (0.975 * w, b + min(0.08, h * 0.2)),
            (0.93 * w, b),
        ]

    def cabin_section(self, z):
        a = self.a
        top = self.cabin_top(z)
        bot = self.body_top(z) - 0.03
        w = self.width(z) * a['GH']
        h = max(0.0, top - bot)
        wt = w * 0.8
        return [
            (0.0, top + 0.012),
            (0.5 * wt, top + 0.006),
            (0.88 * wt, top - min(0.03, h * 0.15)),
            (wt, top - min(0.07, h * 0.3)),
            (w * 0.94, bot + h * 0.45),
            (w * 1.02, bot),
        ]


class Mesh:
    def __init__(self, name):
        self.name = name
        self.v = []
        self.f = []

    def add(self, p):
        self.v.append(p)
        return len(self.v)

    def loft(self, sections, closed=False, flip=False):
        """sections: list of point lists (same length) along z. Creates quads between them."""
        idx = [[self.add(p) for p in sec] for sec in sections]
        for i in range(len(idx) - 1):
            a, b = idx[i], idx[i + 1]
            n = len(a)
            for j in range(n - 1 if not closed else n):
                j2 = (j + 1) % n
                q = (a[j], a[j2], b[j2], b[j])
                if flip:
                    q = q[::-1]
                self.f.append((q[0], q[1], q[2]))
                self.f.append((q[0], q[2], q[3]))
        return idx

    def fan(self, ring, center, flip=False):
        c = self.add(center)
        ids = [self.add(p) for p in ring]
        for j in range(len(ids) - 1):
            tri = (c, ids[j], ids[j + 1])
            self.f.append(tri[::-1] if flip else tri)


def full_ring(half, z, mirror=True):
    """Converts a right-half section (top centre first) into a full ring in studs, left to right."""
    right = [(x, y) for x, y in half]
    left = [(-x, y) for x, y in reversed(half[1:])]
    pts = left + right if mirror else right
    return pts


def to_studs(car, x, y, z):
    return (x * S, y * S, (-car.a['L'] / 2 + z) * S)


def build_car(name, a, seed):
    car = Car(a)
    L = a['L']
    meshes = {}

    # Body ---------------------------------------------------------------------------------
    body = Mesh(name + '__Body')
    zs = car.stations(0, L)
    secs = []
    for z in zs:
        half = car.body_section(z)
        ring = list(reversed(half))  # bottom right ... top centre
        ring = [(-x, y) for x, y in half[::-1][:-1]] if False else ring
        full = [(-x, y) for (x, y) in reversed(list(reversed(half)))]
        # left side bottom -> top centre -> right side bottom
        left = [(-x, y) for (x, y) in reversed(half)]
        right = [(x, y) for (x, y) in half[1:]]
        secs.append([to_studs(car, x, y, z) for x, y in left + right])
    body.loft(secs, flip=True)
    # end caps (nose and tail) as fans
    for z, flip in ((zs[0], False), (zs[-1], True)):
        half = car.body_section(z)
        left = [(-x, y) for (x, y) in reversed(half)]
        right = [(x, y) for (x, y) in half[1:]]
        b = car.side_bottom(z)
        # closed ring: ... right side bottom -> bottom centre -> left side bottom
        ring = [to_studs(car, x, y, z) for x, y in left + right + [(0, b), left[0]]]
        cy = (car.top_smooth(z) + b) / 2
        body.fan(ring, to_studs(car, 0, cy, z), flip=flip)
    # underbody between the sides (closes the shell from below)
    under = []
    for z in zs:
        b = car.side_bottom(z)
        w = car.width(z) * 0.93
        under.append([to_studs(car, -w, b, z), to_studs(car, w, b, z)])
    body.loft(under, flip=False)
    meshes['Body'] = body

    # Greenhouse: glass sides everywhere, roof top between WS1 and R1 -------------------------
    glass = Mesh(name + '__Glass')
    roof = Mesh(name + '__Roof')
    zs = [z for z in car.stations(a['WS0'], a['RW1'], 0.08)]
    side_secs, top_secs_g, top_secs_r = [], [], []
    for z in zs:
        half = car.cabin_section(z)
        # sides: points 2..end (right), mirrored left
        side_r = [to_studs(car, x, y, z) for x, y in half[2:]]
        side_l = [to_studs(car, -x, y, z) for x, y in half[2:]]
        top = [to_studs(car, -x, y, z) for x, y in reversed(half[:3])] + [to_studs(car, x, y, z) for x, y in half[1:3]]
        side_secs.append((side_l, side_r, top, z))
    for i in range(len(side_secs) - 1):
        l0, r0, t0, z0 = side_secs[i]
        l1, r1, t1, z1 = side_secs[i + 1]
        glass.loft([r0, r1], flip=True)
        glass.loft([l0, l1], flip=False)
        zc = (z0 + z1) / 2
        target = roof if a['WS1'] <= zc <= a['R1'] else glass
        target.loft([t0, t1], flip=True)
    meshes['Glass'] = glass
    meshes['Roof'] = roof

    # Tarp: cloth draped over the whole car with folds and a flared hem ----------------------
    rnd = random.Random(seed)
    tarp = Mesh(name + '__Tarp')
    over = 0.07
    z_start, z_end = -0.18, L + 0.18
    zs = []
    z = z_start
    while z <= z_end + 1e-6:
        zs.append(z)
        z += 0.1
    phases = [rnd.uniform(0, 6.28) for _ in range(6)]
    n_around = 15  # points from top centre to hem (half)

    def high(z):
        zc = max(0, min(L, z))
        h = car.top_adj(zc)
        if a['WS0'] - 0.25 <= zc <= a['RW1'] + 0.35:
            h = max(h, car.cabin_top(min(max(zc, a['WS0']), a['RW1'])))
        if a['Bed'] and a['Bed'][0] - 0.05 <= zc <= a['Bed'][1]:
            h = max(h, a['Bed'][2])  # cloth rests on the bed walls
        return h

    def cloth_top(z):
        # cloth bridges between high points (smoothing along z)
        vals = [high(z + d) for d in (-0.35, -0.2, -0.1, 0, 0.1, 0.2, 0.35)]
        return max(high(z), sum(vals) / len(vals)) + over

    def smoothstep(e0, e1, x):
        t = max(0.0, min(1.0, (x - e0) / max(1e-6, e1 - e0)))
        return t * t * (3 - 2 * t)

    n_top, n_side = 10, 9
    secs = []
    for z in zs:
        zc = max(0, min(L, z))
        end_t = 0.0
        if z < 0:
            end_t = -z / 0.18
        elif z > L:
            end_t = (z - L) / 0.18
        def body_h(zz):
            zz = max(0, min(L, zz))
            h = car.top_adj(zz)
            if a['Bed'] and a['Bed'][0] - 0.05 <= zz <= a['Bed'][1]:
                h = max(h, a['Bed'][2])
            return h
        belt = sum(body_h(zc + d) for d in (-0.15, 0, 0.15)) / 3 + over
        top = max(cloth_top(z), belt)
        w = car.width(zc) + over + 0.02
        cabw = car.width(zc) * a['GH'] * 0.85
        # fade towards the curtains at both ends
        top = top - (top - 0.25) * 0.75 * end_t
        belt = belt - (belt - 0.25) * 0.75 * end_t
        w *= (1 - 0.2 * end_t)
        pts = []
        for i in range(n_top + 1):
            x = w * i / n_top
            cab = top - (top - belt) * smoothstep(0.45 * cabw, 1.08 * cabw, x)
            body = belt - 0.15 * smoothstep(0.7 * w, w, x)
            y = max(cab, body) if x < w * 0.99 else body
            pts.append([x, y])
        y_edge = pts[-1][1]
        for j in range(1, n_side + 1):
            v = j / n_side
            y = y_edge - (y_edge - 0.015) * (v ** 0.9)
            x = w + 0.02 * math.sin(v * 3.1) + 0.17 * max(0, v - 0.65) / 0.35
            pts.append([x, y])
        out = []
        n = len(pts)
        for k, (x, y) in enumerate(pts):
            u = k / (n - 1)
            amp = 0.006 + 0.04 * (u ** 2.2)
            ripple = amp * (math.sin(z * 6.0 + phases[0] + u * 3) + 0.6 * math.sin(z * 13 + phases[1]) + 0.4 * math.sin(u * 17 + z * 3 + phases[2]))
            # soft wrinkles on the top surface (diagonal folds) and a little sag
            wrinkle = 0.014 * math.sin(x * 9 + z * 7 + phases[4]) * math.sin(z * 3.3 + phases[5]) * (1 - u)
            y2 = y + 0.008 * math.sin(z * 9 + phases[3] + u * 5) * (1 - u) + wrinkle
            out.append((max(0.0, x + ripple), max(0.01, y2)))
        left = [to_studs(car, -x, y, z) for x, y in reversed(out)]
        right = [to_studs(car, x, y, z) for x, y in out[1:]]
        secs.append(left + right)
    tarp.loft(secs, flip=True)
    # end curtains (front / back): fan from the end ring to a point below its centre
    for sec, flip in ((secs[0], False), (secs[-1], True)):
        cx = 0
        cz = sec[0][2]
        cy = sum(p[1] for p in sec) / len(sec) * 0.5
        tarp.fan(sec, (cx, cy, cz), flip=flip)
    meshes['Tarp'] = tarp
    return meshes


def write_obj(all_meshes, path):
    out = ['# Car Market Tycoon car meshes (studs, Y up, front -Z). Generated by tools/gen_meshes.py']
    offset = 0
    # origin marker: tiny tetrahedron at (0,0,0) so relative positions survive the import
    out.append('o Origin')
    # symmetric octahedron: its bounding-box centre is exactly the car origin
    d = 0.1
    marker = [(d, 0, 0), (-d, 0, 0), (0, d, 0), (0, -d, 0), (0, 0, d), (0, 0, -d)]
    for p in marker:
        out.append('v %.4f %.4f %.4f' % p)
    for f in [(1, 3, 5), (3, 2, 5), (2, 4, 5), (4, 1, 5), (3, 1, 6), (2, 3, 6), (4, 2, 6), (1, 4, 6)]:
        out.append('f %d %d %d' % tuple(i + offset for i in f))
    offset += 6
    tri_total = 0
    for m in all_meshes:
        if not m.f:
            continue
        out.append('o ' + m.name)
        for p in m.v:
            out.append('v %.3f %.3f %.3f' % p)
        for f in m.f:
            out.append('f %d %d %d' % (f[0] + offset, f[1] + offset, f[2] + offset))
        offset += len(m.v)
        tri_total += len(m.f)
        if len(m.f) > 20000:
            print('WARNING: %s has %d triangles (Roblox limit 20000)' % (m.name, len(m.f)))
    open(path, 'w').write('\n'.join(out) + '\n')
    return tri_total


if __name__ == '__main__':
    arch = parse_archetypes()
    meshes = []
    built = {}
    for i, (name, a) in enumerate(arch.items()):
        parts = build_car(name, a, i * 17 + 3)
        built[name] = parts
        meshes += list(parts.values())
    tris = write_obj(meshes, os.path.join(ROOT, 'assets/CarMeshes.obj'))
    print('archetypes:', len(arch), 'triangles:', tris)
    if '--pickle' in sys.argv:
        import pickle
        pickle.dump({k: {n: (m.v, m.f) for n, m in v.items()} for k, v in built.items()}, open('/tmp/claude-0/render/meshes.pkl', 'wb'))
