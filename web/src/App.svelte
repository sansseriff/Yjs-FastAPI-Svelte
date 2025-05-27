<script lang="ts">
  import svelteLogo from "./assets/SvelteLogo.svg";
  import yjsLogo from "./assets/YjsLogo.png";
  import fastAPIlogo from "./assets/FastAPILogo.svg";

  // import Counter from './lib/Counter.svelte'; // We'll replace Counter with Yjs demo

  import * as Y from "yjs";
  import { WebsocketProvider } from "y-websocket";
  import { onMount, onDestroy } from "svelte";

  const ydoc = new Y.Doc();
  // Update the WebSocket URL to include the "/ws" prefix, matching the FastAPI mount path.
  // The room name "my-shared-document" will be the path segment after "/ws".
  const wsProvider = new WebsocketProvider(
    "ws://localhost:8000/ws",
    "my-shared-document",
    ydoc
  );

  // Get a Y.Map type
  const yMap = ydoc.getMap("sharedData");

  let sharedText: string = $state("");
  let awarenessDisplay: { id: number; name: string; color: string }[] = $state(
    []
  );

  onMount(() => {
    wsProvider.on("status", (event: { status: string }) => {
      console.log("WebSocket status:", event.status); // e.g. "connected" or "disconnected"
    });

    // Initialize sharedText from yMap or set a default
    const currentText = yMap.get("editableText");
    if (currentText === undefined) {
      yMap.set("editableText", "Hello from Svelte!");
      sharedText = "Hello from Svelte!";
    } else {
      sharedText = currentText as string;
    }

    // Observe changes on the yMap
    const observeFn = () => {
      const newText = yMap.get("editableText") as string | undefined;
      if (newText !== undefined) {
        sharedText = newText;
      }
    };
    yMap.observe(observeFn);

    // Awareness (optional, to show connected users)
    wsProvider.awareness.setLocalStateField("user", {
      name: "User " + Math.floor(Math.random() * 100),
      color:
        "#" +
        Math.floor(Math.random() * 0xffffff)
          .toString(16)
          .padStart(6, "0"), // random color
    });

    const updateAwareness = () => {
      awarenessDisplay = Array.from(
        wsProvider.awareness.getStates().values()
      ).map((state: any, id: any) => ({
        id: id, // The clientID
        name: state.user?.name || "Anonymous",
        color: state.user?.color || "#000000",
      }));
    };

    wsProvider.awareness.on("change", updateAwareness);
    updateAwareness(); // Initial update

    return () => {
      yMap.unobserve(observeFn);
      wsProvider.awareness.off("change", updateAwareness);
      wsProvider.disconnect(); // Or wsProvider.destroy() if you won't reuse it
    };
  });

  function handleInput(event: Event) {
    const newText = (event.target as HTMLInputElement).value;
    sharedText = newText; // Update local state immediately for responsiveness
    yMap.set("editableText", newText); // Set the value in Y.Map, which syncs
  }
</script>

<main>
  <div>
    <a href="https://svelte.dev" target="_blank" rel="noreferrer">
      <img src={svelteLogo} class="logo svelte" alt="Svelte Logo" />
    </a>

    <a href="https://yjs.dev/" target="_blank" rel="noreferrer">
      <img src={yjsLogo} class="logo svelte" alt="Svelte Logo" />
    </a>
    <a href="https://fastapi.tiangolo.com/" target="_blank" rel="noreferrer">
      <img src={fastAPIlogo} class="logo" alt="Vite Logo" />
    </a>
  </div>
  <h1>Svelte + Yjs + FastAPI</h1>

  <p>
    CRDT functionality added to FastAPI using <a
      href="https://github.com/y-crdt/pycrdt">pycrdt</a
    >
    and
    <a href="https://github.com/y-crdt/pycrdt-websocket">pycrdt-websocket</a>.
  </p>
  <div class="card">
    <h2>Shared Editable Text:</h2>
    <input
      type="text"
      value={sharedText}
      oninput={handleInput}
      style="width: 80%; padding: 0.5em; margin-bottom: 1em;"
    />
    <p>Current shared value: <strong>{sharedText}</strong></p>
  </div>

  <div class="card">
    <h2>Connected Users (Awareness):</h2>
    {#if awarenessDisplay.length > 0}
      <ul>
        {#each awarenessDisplay as user (user.id)}
          <li style="color: {user.color};">
            {user.name} (ID: {user.id})
            {#if user.id === wsProvider.awareness.clientID}
              <strong>(You)</strong>
            {/if}
          </li>
        {/each}
      </ul>
    {:else}
      <p>No other users connected or awareness not yet updated.</p>
    {/if}
  </div>

  <p>
    Edit the text field. If you open this page in another browser tab, the text
    will synchronize.
  </p>

  <p class="read-the-docs">Click on the Vite and Svelte logos to learn more</p>
</main>

<style>
  .logo {
    height: 6em;
    padding: 1.5em;
    will-change: filter;
    transition: filter 300ms;
  }
  .logo:hover {
    filter: drop-shadow(0 0 2em #646cffaa);
  }
  .logo.svelte:hover {
    filter: drop-shadow(0 0 2em #ff3e00aa);
  }
  .read-the-docs {
    color: #888;
  }
</style>
