import * as THREE from 'three';
import RAPIER from '@dimforge/rapier2d-compat';

const W = 720;
const H = 1280;
const STONE_W = 180;
const STONE_H = 56;
const GROUND_Y = 970;
const CAMERA_START = 820;
const CARRIER_GAP = 175;
const CARRIER_SPEED = 330;
const DROP_PUSH = 260;
const MARGIN = 90;
const SCALE = 10.4 / H;
const START_SCENE_Y = 5.1;

const canvas = document.querySelector('#world');
const scoreEl = document.querySelector('#score');
const coinsEl = document.querySelector('#coins');
const loadingEl = document.querySelector('#loading');
const messageEl = document.querySelector('#message');
const buttons = [...document.querySelectorAll('[data-boost]')];

let renderer;
let scene;
let camera;
let world;
let eventQueue;
let clock;
let zenVideo;
let carrier;
let carrierDirection = 1;
let currentStone = null;
let stones = [];
let colliderOwners = new Map();
let score = 0;
let coins = Number(localStorage.getItem('bt-coins') || 0);
let topY = GROUND_Y;
let cameraY = CAMERA_START;
let state = 'loading';
let slowUntil = 0;
let magnet = false;
let lastPlaced = null;
let accumulator = 0;
let lastTime = performance.now();
const textures = [];

await RAPIER.init();
setupRenderer();
setupPhysics();
await Promise.all([loadBackdrop(), loadStoneTextures()]);
setupPedestal();
spawnCarrier();
state = 'waiting';
loadingEl.hidden = true;
updateHud();
requestAnimationFrame(frame);

function setupRenderer() {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.setSize(W, H, false);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.62;

  scene = new THREE.Scene();
  scene.background = new THREE.Color('#102a26');
  camera = new THREE.OrthographicCamera(-2.925, 2.925, 5.2, -5.2, 0.1, 80);
  camera.position.set(0, START_SCENE_Y, 18.5);
  camera.lookAt(0, START_SCENE_Y - 0.35, 0);
  clock = new THREE.Clock();

  scene.add(new THREE.HemisphereLight(0xc8e5dc, 0x17251e, 0.72));
  const sun = new THREE.DirectionalLight(0xffd1a0, 1.05);
  sun.position.set(-7, 12, 12);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024);
  sun.shadow.camera.left = -8;
  sun.shadow.camera.right = 8;
  sun.shadow.camera.top = 12;
  sun.shadow.camera.bottom = -12;
  scene.add(sun);
}

function setupPhysics() {
  world = new RAPIER.World({ x: 0, y: 1180 });
  world.timestep = 1 / 60;
  eventQueue = new RAPIER.EventQueue(true);
  const body = world.createRigidBody(RAPIER.RigidBodyDesc.fixed().setTranslation(W / 2, 1000));
  const collider = world.createCollider(
    RAPIER.ColliderDesc.cuboid(STONE_W / 2, 30).setFriction(0.9).setRestitution(0), body
  );
  colliderOwners.set(collider.handle, { kind: 'ground' });
}

async function loadBackdrop() {
  zenVideo = document.createElement('video');
  zenVideo.src = './assets/zen_blender_loop.mp4';
  zenVideo.muted = true;
  zenVideo.loop = true;
  zenVideo.playsInline = true;
  zenVideo.preload = 'auto';
  await new Promise((resolve, reject) => {
    zenVideo.addEventListener('canplay', resolve, { once: true });
    zenVideo.addEventListener('error', () => reject(new Error('Zen video could not load')), { once: true });
    zenVideo.load();
  });
  const texture = new THREE.VideoTexture(zenVideo);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  const plane = new THREE.Mesh(
    new THREE.PlaneGeometry(5.85, 10.4),
    new THREE.MeshBasicMaterial({ map: texture, toneMapped: false })
  );
  plane.position.set(0, START_SCENE_Y, -6);
  scene.add(plane);
  window.BT_zenVideo = zenVideo;
  zenVideo.play().catch(() => {});
}

async function loadStoneTextures() {
  const loader = new THREE.TextureLoader();
  for (let i = 1; i <= 8; i++) {
    const texture = await loader.loadAsync(`./assets/stone_${i}.png`);
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.magFilter = THREE.NearestFilter;
    texture.minFilter = THREE.NearestFilter;
    textures.push(texture);
  }
}

function setupPedestal() {
  // The approved background already contains the foundation. Rapier keeps the
  // independent fixed collider, but no second visual platform is drawn here.
}

function spawnCarrier() {
  const texture = textures[Math.floor(Math.random() * textures.length)];
  carrier = {
    x: MARGIN,
    y: topY - CARRIER_GAP,
    texture,
    mesh: makeStoneMesh(texture)
  };
  scene.add(carrier.mesh);
  carrierDirection = 1;
  state = 'waiting';
}

function makeStoneMesh(texture) {
  const material = new THREE.MeshStandardMaterial({ map: texture, transparent: true, alphaTest: 0.45, roughness: 0.82 });
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(STONE_W * SCALE, STONE_H * SCALE), material);
  mesh.position.z = 12;
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

function drop() {
  const x = magnet && lastPlaced ? lastPlaced.body.translation().x : carrier.x;
  const body = world.createRigidBody(
    RAPIER.RigidBodyDesc.dynamic()
      .setTranslation(x, carrier.y)
      .setLinvel(0, DROP_PUSH)
      .setLinearDamping(0.3)
      .setAngularDamping(0.4)
  );
  const collider = world.createCollider(
    RAPIER.ColliderDesc.cuboid(STONE_W / 2, STONE_H / 2)
      .setDensity(1 / (STONE_W * STONE_H))
      .setFriction(0.9)
      .setRestitution(0)
      .setActiveEvents(RAPIER.ActiveEvents.COLLISION_EVENTS),
    body
  );
  const stone = { body, collider, mesh: carrier.mesh, placed: false, minY: carrier.y, rotationBase: 0 };
  colliderOwners.set(collider.handle, stone);
  stones.push(stone);
  currentStone = stone;
  carrier = null;
  magnet = false;
  state = 'dropping';
}

function placeStone(stone) {
  if (stone.placed || state === 'gameover') return;
  stone.placed = true;
  stone.minY = stone.body.translation().y;
  stone.rotationBase = stone.body.rotation();
  topY = Math.min(topY, stone.body.translation().y - STONE_H / 2);
  score += 1;
  coins += score % 10 === 0 ? score + 1 : 1;
  lastPlaced = stone;
  currentStone = null;
  localStorage.setItem('bt-coins', String(coins));
  updateHud();
  spawnCarrier();
}

function physicsStep() {
  world.step(eventQueue);
  eventQueue.drainCollisionEvents((h1, h2, started) => {
    if (!started) return;
    const a = colliderOwners.get(h1);
    const b = colliderOwners.get(h2);
    if (a === currentStone || b === currentStone) placeStone(currentStone);
  });

  for (const stone of stones) {
    const p = stone.body.translation();
    stone.mesh.position.copy(screenToWorld(p.x, p.y));
    stone.mesh.position.z = 12;
    stone.mesh.rotation.z = -stone.body.rotation();
    if (!stone.placed && p.y > topY + 230) return gameOver();
    if (stone.placed) {
      stone.minY = Math.min(stone.minY, p.y);
      if (Math.abs(stone.body.rotation() - stone.rotationBase) > 0.85 || p.y > stone.minY + 150) return gameOver();
    }
  }
}

function screenToWorld(x, y) {
  return new THREE.Vector3((x - W / 2) * SCALE, START_SCENE_Y - (y - CAMERA_START) * SCALE, 12);
}

function updateCamera(dt) {
  const target = topY - 150;
  cameraY += (target - cameraY) * Math.min(dt * 3, 1);
  camera.position.y = START_SCENE_Y + (CAMERA_START - cameraY) * SCALE;
  camera.lookAt(0, camera.position.y - 0.35, 0);
}

function gameOver() {
  state = 'gameover';
  if (carrier) {
    scene.remove(carrier.mesh);
    carrier = null;
  }
  messageEl.hidden = false;
  window.BT_finish?.(score);
}

function restart() {
  for (const stone of stones) {
    scene.remove(stone.mesh);
    world.removeRigidBody(stone.body);
  }
  stones = [];
  colliderOwners = new Map([...colliderOwners].filter(([, owner]) => owner.kind === 'ground'));
  score = 0;
  topY = GROUND_Y;
  cameraY = CAMERA_START;
  lastPlaced = null;
  currentStone = null;
  messageEl.hidden = true;
  spawnCarrier();
  updateHud();
}

function frame(now) {
  const dt = Math.min((now - lastTime) / 1000, 0.05);
  lastTime = now;
  accumulator += dt;
  clock.getDelta();

  if (state === 'waiting' && carrier) {
    const speed = now < slowUntil ? CARRIER_SPEED * 0.42 : CARRIER_SPEED;
    carrier.x += carrierDirection * speed * dt;
    if (carrier.x >= W - MARGIN || carrier.x <= MARGIN) {
      carrier.x = THREE.MathUtils.clamp(carrier.x, MARGIN, W - MARGIN);
      carrierDirection *= -1;
    }
    carrier.mesh.position.copy(screenToWorld(carrier.x, carrier.y));
  }
  while (accumulator >= 1 / 60) {
    if (state !== 'loading' && state !== 'gameover') physicsStep();
    accumulator -= 1 / 60;
  }
  updateCamera(dt);
  renderer.render(scene, camera);
  requestAnimationFrame(frame);
}

function updateHud() {
  scoreEl.textContent = score;
  coinsEl.textContent = coins;
  buttons.forEach((button) => {
    button.disabled = coins < Number(button.querySelector('b').textContent) || state === 'gameover';
  });
}

function activateBoost(kind) {
  const cost = { freeze: 40, slow: 35, magnet: 30 }[kind];
  if (coins < cost || state === 'gameover') return;
  coins -= cost;
  if (kind === 'slow') slowUntil = performance.now() + 6000;
  if (kind === 'magnet') magnet = true;
  if (kind === 'freeze') {
    stones.forEach(({ body }) => {
      const v = body.linvel();
      body.setLinvel({ x: v.x * 0.4, y: v.y * 0.4 }, true);
      body.setAngvel(body.angvel() * 0.25, true);
    });
  }
  localStorage.setItem('bt-coins', String(coins));
  updateHud();
}

document.querySelector('#game').addEventListener('pointerdown', (event) => {
  if (event.target.closest('button')) return;
  zenVideo?.play().catch(() => {});
  if (state === 'waiting') drop();
  else if (state === 'gameover') restart();
});
buttons.forEach((button) => button.addEventListener('click', () => activateBoost(button.dataset.boost)));
window.addEventListener('resize', () => renderer?.setPixelRatio(Math.min(devicePixelRatio, 2)));
window.Telegram?.WebApp?.ready();
window.Telegram?.WebApp?.expand();
