import QtQuick
import Quickshell

Item {
    id: root

    required property var screenSize
    required property var borderThickness
    required property string imgPath
    // Size multiplier from config (1.0 = native 128px pack), clamped so the
    // geometry can never degenerate; artScale is the effective multiplier
    property real sizeScale: 1
    property real floorOffset: 0
    property real ceilingOffset: 0
    property real leftOffset: 0
    property real rightOffset: 0

    readonly property real artScale: Math.max(0.25, Math.min(4, sizeScale))
    readonly property real size: 128 * artScale

    readonly property real floorY: screenSize.height - size - borderThickness - floorOffset
    readonly property real minX: leftOffset
    readonly property real maxX: screenSize.width - size - rightOffset
    readonly property real ceilingY: ceilingOffset + borderThickness
    // Standard-layout ceiling frames (23-25) draw the pet ~47px down the
    // canvas; lift the canvas so its visible body touches the ceiling line
    readonly property real ceilingLift: 47
    // Climb frames (12-14) draw the pet ~55px into the canvas (on the wall
    // side); the canvas is shifted by this so the body — not the canvas edge —
    // touches the wall while the pet keeps facing it
    readonly property real climbArtOffset: 55

    property real vx: 0
    property real vy: 0
    readonly property real gravity: 2

    property bool onGround: false
    property bool dragging: false
    property int dragPose: 0
    property bool climbing: false
    property bool ceilingWalk: false
    property int climbDir: 1
    property point dragOffset
    property real lastX: 0
    property real lastY: 0
    property real dragVx: 0
    property real dragVy: 0
    property int walkTarget: -1

    property string currentAnim: "idle"
    property int frameIndex: 0
    property bool facingRight: true

    // This sprite's input region, registered on the hosting window's mask so
    // clicks pass through everywhere except the sprite itself
    property var maskHost: null
    readonly property Region inputMask: Region {
        item: root
    }

    // Frame tables for the standard 46-image shimeji layout
    // 1-3 walk · 4 fall · 5-10 drag poses (H-up, H-down, diag-up, diag-down,
    // steep-up, steep-down) · 11 idle · 12-14 climb · 15-17 ice cream ·
    // 18/21 saddened flat · 19 sit happy · 20 neutral flat · 22 stand happy ·
    // 23-25 ceiling walk · 26-29 pizza thought · 30-33 chicken · 37 jump away ·
    // 38-41 donut · 34-36 window grab and 42-46 unused
    readonly property var anims: ({
        walk: ["shime1.png", "shime2.png", "shime3.png"],
        fall: ["shime4.png"],
        drag: ["shime5.png", "shime6.png", "shime7.png", "shime8.png", "shime9.png", "shime10.png"],
        idle: ["shime11.png"],
        climb: ["shime12.png", "shime13.png", "shime14.png"],
        snack: ["shime15.png", "shime16.png", "shime17.png"],
        sad: ["shime18.png", "shime21.png"],
        sit: ["shime19.png"],
        flat: ["shime20.png"],
        happy: ["shime22.png"],
        ceiling: ["shime23.png", "shime24.png", "shime25.png"],
        pizza: ["shime26.png", "shime27.png", "shime28.png", "shime29.png"],
        munch: ["shime30.png", "shime31.png", "shime32.png", "shime33.png"],
        jump: ["shime37.png"],
        land: ["shime20.png"],
        donut: ["shime38.png", "shime39.png", "shime40.png", "shime41.png"]
    })

    function animFrame(anim, index) {
        const list = anims[anim];
        return list ? list[index % list.length] : "";
    }

    function animInterval(anim) {
        if (anim === "walk" || anim === "ceiling")
            return 140;
        if (anim === "climb")
            return 160;
        if (anim === "fall" || anim === "jump")
            return 100;
        if (anim === "snack" || anim === "munch" || anim === "donut")
            return 260;
        if (anim === "pizza")
            return 320;
        return 240;
    }

    // The drag pose roughly matching the cursor's velocity direction
    // (index into the drag table: 0=shime5 H-up, 1=shime6 H-down,
    //  2=shime7 diag-up, 3=shime8 diag-down, 4=shime9 steep-up, 5=shime10 steep-down)
    function dragPoseFor(vx, vy) {
        const speed = Math.abs(vx) + Math.abs(vy);
        if (speed < 4)
            return 0; // barely moving: hang horizontally, slightly upwards
        const angle = Math.atan2(-vy, Math.abs(vx)) * 180 / Math.PI; // up = positive
        if (angle > 50)
            return 4;
        if (angle > 22)
            return 2;
        if (angle >= 0)
            return 0;
        if (angle > -22)
            return 1;
        if (angle > -50)
            return 3;
        return 5;
    }

    // Pick a random idle pose (11 idle, 22 standing happy, 19 sitting happy,
    // 20 neutral flat, 18/21 saddened flat)
    function pickIdle() {
        const roll = Math.random();
        if (roll < 0.25)
            currentAnim = "idle";
        else if (roll < 0.45)
            currentAnim = "happy";
        else if (roll < 0.65)
            currentAnim = "sit";
        else if (roll < 0.8)
            currentAnim = "flat";
        else
            currentAnim = "sad";
        frameIndex = 0;
    }

    function startSnack() {
        const roll = Math.random();
        if (roll < 0.4)
            currentAnim = "snack";
        else if (roll < 0.7)
            currentAnim = "munch";
        else
            currentAnim = "donut";
        frameIndex = 0;
    }

    function walkRandom() {
        const margin = 100;
        const lo = Math.max(minX + margin, minX);
        const hi = Math.min(maxX - margin, maxX);
        if (hi <= lo) {
            walkTarget = (minX + maxX) / 2;
        } else {
            walkTarget = lo + Math.random() * (hi - lo);
        }
        currentAnim = "walk";
        facingRight = walkTarget > root.x;
        frameIndex = 0;
    }

    // Walk to the nearest reserved wall, climb it, then walk the ceiling.
    // The target is the wall itself (minX/maxX already account for side bars)
    // and climbDir pins the ascend phase to that exact edge — a fixed-offset
    // target can be unreachable once a bar reserves the edge (the pet would
    // walk at the wall forever without climbing).
    function startClimb() {
        const nearLeft = root.x + 64 < screenSize.width / 2;
        climbDir = nearLeft ? -1 : 1;
        facingRight = climbDir > 0;
        climbing = true;
        ceilingWalk = false;
        walkTarget = climbDir < 0 ? minX : maxX;
        currentAnim = "walk";
        frameIndex = 0;
    }

    function hop() {
        onGround = false;
        vy = -7 - Math.random() * 3;
        vx = (Math.random() - 0.5) * 6;
        currentAnim = "jump";
        frameIndex = 0;
    }

    function tick(dt) {
        if (dragging)
            return;

        const timeScale = dt / 0.030;

        // Ascending the wall (12-14): pinned near the edge, constant climb
        // speed. The canvas is shifted by the art offset so the mirrored
        // (wall-facing) pet's body hugs the wall itself
        if (climbing && walkTarget < 0) {
            root.y += vy * timeScale;
            root.x = climbDir < 0 ? minX - climbArtOffset * artScale : maxX + climbArtOffset * artScale;

            if (root.y <= ceilingY) {
                // Lift onto the ceiling so the visible body (not the canvas
                // edge) meets the reserved line
                root.y = ceilingY - ceilingLift * artScale;
                climbing = false;
                ceilingWalk = true;
                walkTarget = Math.max(minX, Math.min(maxX, minX + 60 + Math.random() * Math.max(1, maxX - minX - 120)));
                currentAnim = "ceiling";
                frameIndex = 0;
            }
            return;
        }

        // Walking along the ceiling (23-25), then dropping off
        if (ceilingWalk) {
            if (walkTarget < 0) {
                ceilingWalk = false;
                onGround = false;
                vy = 2;
                vx = 0;
                currentAnim = "jump";
                frameIndex = 0;
                return;
            }

            const dxc = walkTarget - root.x;
            if (Math.abs(dxc) < 6) {
                walkTarget = -1;
                ceilingWalk = false;
                onGround = false;
                vy = 2;
                vx = (Math.random() < 0.5 ? -1 : 1) * (1.5 + Math.random() * 2);
                currentAnim = "jump";
                frameIndex = 0;
                return;
            }

            vx = Math.sign(dxc) * 1.5;
            facingRight = vx > 0;
            root.x = Math.max(minX, Math.min(maxX, root.x + vx * timeScale));
            return;
        }

        // Airborne: gravity, fall frame (4) or jump frame (37) while rising
        if (!onGround) {
            vy += gravity * timeScale;
            vx *= Math.pow(0.98, timeScale);
            if (vy > 0 && currentAnim !== "fall") {
                currentAnim = "fall";
                frameIndex = 0;
            }
        }

        if (walkTarget >= 0) {
            const dx = walkTarget - root.x;
            // Reaching the reserved wall also counts as arrival (the clamp can
            // leave the pet a tick short of the exact target)
            const atWall = climbing && ((climbDir < 0 && root.x <= minX + 2) || (climbDir > 0 && root.x >= maxX - 2));
            if (Math.abs(dx) < 8 || atWall) {
                walkTarget = -1;
                vx = 0;

                if (climbing) {
                    // Reached the edge: start ascending (12-14). The pet faces
                    // the wall it climbs; the canvas shift in the ascend phase
                    // keeps its body flush with the wall
                    currentAnim = "climb";
                    frameIndex = 0;
                    vy = -2.5;
                    onGround = false;
                    facingRight = climbDir > 0;
                } else {
                    pickIdle();
                }
            } else {
                vx = Math.sign(dx) * 2.5;
                facingRight = vx > 0;
                if (currentAnim !== "walk") {
                    currentAnim = "walk";
                    frameIndex = 0;
                }
            }
        }

        root.x += vx * timeScale;
        root.y += vy * timeScale;

        if (root.x < minX) {
            root.x = minX;
            vx = Math.abs(vx) * 0.9;
        } else if (root.x > maxX) {
            root.x = maxX;
            vx = -Math.abs(vx) * 0.9;
        }

        if (root.y > floorY) {
            root.y = floorY;
            if (Math.abs(vy) > 3) {
                // Bounce, shedding half the speed each hit (always terminates)
                vy = -Math.abs(vy) * 0.5;
            } else {
                vy = 0;
                vx = 0;
                if (!onGround) {
                    onGround = true;
                    currentAnim = "land";
                    frameIndex = 0;
                    landTimer.restart();
                    if (Math.random() < 0.15 * timeScale)
                        walkRandom();
                }
            }
        } else if (vy < 0 && root.y < ceilingY) {
            // Only rising pets bounce off the ceiling; a pet dropping off it
            // (canvas lifted by ceilingLift) must fall through this line
            root.y = ceilingY;
            vy = Math.abs(vy) * 0.5;
        }
    }

    x: 0
    y: floorY
    width: root.size
    height: root.size

    Component.onCompleted: {
        if (maskHost)
            maskHost.registerSpriteMask(inputMask);

        const margin = 50;
        x = Math.max(minX + margin, Math.min(maxX - margin, minX + Math.random() * Math.max(1, maxX - minX)));
        y = floorY;
        onGround = true;
        vx = 0;
        vy = 0;
        pickIdle();
    }

    Component.onDestruction: {
        if (maskHost)
            maskHost.unregisterSpriteMask(inputMask);
    }

    onDraggingChanged: {
        if (dragging) {
            currentAnim = "drag";
            frameIndex = dragPose;
        } else {
            climbing = false;
            ceilingWalk = false;
            walkTarget = -1;
            vx = Math.max(-20, Math.min(20, dragVx * 2));
            vy = Math.max(-20, Math.min(20, dragVy * 2));
            if (Math.abs(vx) < 1)
                vx = 0;
            if (Math.abs(vy) < 1)
                vy = 0;
            onGround = false;
            currentAnim = vy < -2 ? "jump" : "fall";
            frameIndex = 0;
        }
    }

    onCurrentAnimChanged: animTimer.restart()

    MouseArea {
        id: grabArea

        // The grab area is the shimeji's full image (the whole scaled canvas)
        anchors.fill: parent
        hoverEnabled: false
        cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton

        onPressed: mouse => {
            dragging = true;
            climbing = false;
            ceilingWalk = false;
            walkTarget = -1;
            landTimer.stop();
            dragOffset = Qt.point(mouse.x, mouse.y);
            lastX = root.x;
            lastY = root.y;
            dragVx = 0;
            dragVy = 0;
            vx = 0;
            vy = 0;
        }

        onPositionChanged: mouse => {
            if (!dragging)
                return;

            const newX = Math.max(minX, Math.min(maxX, root.x + mouse.x - dragOffset.x));
            const newY = Math.max(ceilingY, Math.min(floorY, root.y + mouse.y - dragOffset.y));
            dragVx = newX - lastX;
            dragVy = newY - lastY;
            lastX = newX;
            lastY = newY;
            root.x = newX;
            root.y = newY;

            // Pose tracks the drag direction (5-10)
            const pose = dragPoseFor(dragVx, dragVy);
            if (Math.abs(dragVx) > 2)
                facingRight = dragVx > 0;
            if (pose !== dragPose) {
                dragPose = pose;
                frameIndex = dragPose;
            }
        }

        onReleased: dragging = false
    }

    Image {
        id: spriteImage

        anchors.fill: parent
        source: {
            const fn = root.animFrame(root.currentAnim, root.frameIndex);
            return fn ? "file://" + root.imgPath + fn : "";
        }
        sourceSize.width: 128
        sourceSize.height: 128
        fillMode: Image.PreserveAspectFit

        mirror: root.facingRight
    }

    FrameAnimation {
        id: physicsLoop

        running: true
        onTriggered: root.tick(frameTime)
    }

    Timer {
        id: animTimer

        interval: root.animInterval(root.currentAnim)
        repeat: true
        running: true
        onTriggered: {
            if (!root.dragging)
                root.frameIndex++;
        }
    }

    // Brief settle pose on landing, then a fresh idle pick
    Timer {
        id: landTimer

        interval: 500
        onTriggered: {
            if (root.onGround && !root.dragging)
                root.pickIdle();
        }
    }

    Timer {
        id: behaviorTimer

        interval: 3500 + Math.random() * 4500
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            // Re-roll the period so the loop doesn't become metronomic
            interval = 3500 + Math.random() * 4500;

            if (dragging || climbing || ceilingWalk || !onGround)
                return;

            const roll = Math.random();
            if (roll < 0.18) {
                pickIdle();
            } else if (roll < 0.42) {
                walkRandom();
            } else if (roll < 0.54) {
                startSnack();
            } else if (roll < 0.64) {
                currentAnim = "pizza";
                frameIndex = 0;
            } else if (roll < 0.80) {
                startClimb();
            } else if (roll < 0.88) {
                hop();
            } else {
                currentAnim = "sad";
                frameIndex = 0;
            }
        }
    }
}
