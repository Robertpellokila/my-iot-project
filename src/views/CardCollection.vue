<script setup>
import {
  ref,
  computed,
  onMounted,
} from "vue";

import {
  supabase,
} from "../lib/supabase";


// =========================================================
// STATE
// =========================================================

const cards =
  ref([]);

const loading =
  ref(true);

const errorMessage =
  ref("");

const search =
  ref("");

const selectedElement =
  ref("All");

const selectedCard =
  ref(null);


// =========================================================
// ELEMENTS
// =========================================================

const elements = [
  "All",
  "Fire",
  "Water",
  "Grass",
  "Electric",
  "Ice",
  "Dark",
];


// =========================================================
// LOAD CARDS
// =========================================================

const loadCards =
  async () => {

    loading.value =
      true;

    errorMessage.value =
      "";


    try {

      const {
        data,
        error,
      } =
        await supabase
          .from(
            "game_cards"
          )
          .select("*")
          .order(
            "name",
            {
              ascending:
                true,
            }
          );


      if (
        error
      ) {

        throw error;

      }


      cards.value =
        data ?? [];

    }

    catch (
      error
    ) {

      console.error(
        "Load cards:",
        error
      );


      errorMessage.value =
        error?.message ??
        "Gagal mengambil daftar kartu.";

    }

    finally {

      loading.value =
        false;

    }

  };


// =========================================================
// FILTERED CARDS
// =========================================================

const filteredCards =
  computed(
    () => {

      const keyword =
        search.value
          .trim()
          .toLowerCase();


      return cards.value.filter(
        card => {

          const matchesSearch =
            !keyword
            ||
            String(
              card.name ??
              ""
            )
              .toLowerCase()
              .includes(
                keyword
              )
            ||
            String(
              card.uid ??
              ""
            )
              .toLowerCase()
              .includes(
                keyword
              );


          const matchesElement =
            selectedElement.value ===
              "All"
            ||
            String(
              card.element ??
              ""
            )
              .toLowerCase() ===
            selectedElement.value
              .toLowerCase();


          return (
            matchesSearch
            &&
            matchesElement
          );

        }
      );

    }
  );


// =========================================================
// COLLECTION STATS
// =========================================================

const totalCards =
  computed(
    () =>
      cards.value.length
  );


const elementCount =
  element => {

    if (
      element ===
      "All"
    ) {

      return cards.value.length;

    }


    return cards.value.filter(
      card =>
        String(
          card.element ??
          ""
        )
          .toLowerCase() ===
        String(
          element
        )
          .toLowerCase()
    ).length;

  };


// =========================================================
// ALBUM SLOT COUNT
//
// Supaya terasa seperti binder / album.
// Grid selalu dilengkapi sampai kelipatan 4.
// =========================================================

const emptySlots =
  computed(
    () => {

      const count =
        filteredCards.value
          .length;


      if (
        count === 0
      ) {

        return 8;

      }


      const remainder =
        count % 4;


      return (
        remainder === 0
          ? 0
          : 4 - remainder
      );

    }
  );


// =========================================================
// HELPERS
// =========================================================

const normalizeElement =
  element => {

    return String(
      element ??
      "Neutral"
    )
      .trim()
      .toLowerCase();

  };


const elementLabel =
  element => {

    const labels = {
      fire:
        "FIRE",

      water:
        "WATER",

      grass:
        "GRASS",

      electric:
        "ELECTRIC",

      ice:
        "ICE",

      dark:
        "DARK",
    };


    const normalized =
      normalizeElement(
        element
      );


    return (
      labels[
        normalized
      ]
      ??
      normalized.toUpperCase()
    );

  };


const elementIcon =
  element => {

    const icons = {
      fire:
        "🔥",

      water:
        "💧",

      grass:
        "🌿",

      electric:
        "⚡",

      ice:
        "❄️",

      dark:
        "🌑",
    };


    return (
      icons[
        normalizeElement(
          element
        )
      ]
      ??
      "◉"
    );

  };


const isImageUrl =
  value => {

    if (
      !value
    ) {

      return false;

    }


    const string =
      String(
        value
      );


    return (
      string.startsWith(
        "http://"
      )
      ||
      string.startsWith(
        "https://"
      )
      ||
      string.startsWith(
        "/"
      )
    );

  };


// =========================================================
// CARD DETAIL
// =========================================================

const openCard =
  card => {

    selectedCard.value =
      card;

  };


const closeCard =
  () => {

    selectedCard.value =
      null;

  };


// =========================================================
// MOUNT
// =========================================================

onMounted(
  async () => {

    await loadCards();

  }
);
</script>


<template>
  <main class="collection-page">

    <!-- ===================================================
         BACKGROUND
    ==================================================== -->

    <div class="album-background">

      <div class="album-glow glow-one" />

      <div class="album-glow glow-two" />

      <div class="album-grid" />

    </div>


    <!-- ===================================================
         HEADER
    ==================================================== -->

    <header class="collection-header">

      <div>

        <span class="eyebrow">
          TCG COLLECTION
        </span>


        <h1>
          Card Album
        </h1>


        <p>
          Koleksi seluruh kartu RFID yang sudah terdaftar.
        </p>

      </div>


      <div class="collection-counter">

        <span>
          COLLECTION
        </span>


        <strong>
          {{ totalCards }}
        </strong>


        <small>
          CARDS OWNED
        </small>

      </div>

    </header>


    <!-- ===================================================
         TOOLBAR
    ==================================================== -->

    <section class="album-toolbar">

      <div class="search-box">

        <span>
          ⌕
        </span>


        <input
          v-model="search"
          type="text"
          placeholder="Cari nama kartu atau UID..."
        />

      </div>


      <button
        type="button"
        class="refresh-button"
        :disabled="loading"
        @click="loadCards"
      >

        ↻

        REFRESH

      </button>

    </section>


    <!-- ===================================================
         ELEMENT FILTER
    ==================================================== -->

    <section class="element-filter">

      <button
        v-for="item in elements"
        :key="item"
        type="button"
        class="element-filter-button"
        :class="{
          active:
            selectedElement ===
            item,
        }"
        @click="
          selectedElement =
            item
        "
      >

        <span>

          {{
            item === "All"
              ? "◉"
              : elementIcon(
                  item
                )
          }}

        </span>


        <strong>
          {{ item }}
        </strong>


        <small>
          {{ elementCount(item) }}
        </small>

      </button>

    </section>


    <!-- ===================================================
         LOADING
    ==================================================== -->

    <section
      v-if="loading"
      class="state-panel"
    >

      <div class="loading-ring" />

      <strong>
        OPENING COLLECTION
      </strong>

      <span>
        Loading your cards...
      </span>

    </section>


    <!-- ===================================================
         ERROR
    ==================================================== -->

    <section
      v-else-if="errorMessage"
      class="state-panel error-state"
    >

      <strong>
        FAILED TO LOAD ALBUM
      </strong>

      <span>
        {{ errorMessage }}
      </span>

    </section>


    <!-- ===================================================
         ALBUM
    ==================================================== -->

    <section
      v-else
      class="album-book"
    >

      <!-- LEFT BINDER -->

      <div class="binder-strip">

        <span />

        <span />

        <span />

        <span />

        <span />

      </div>


      <!-- ALBUM HEADER -->

      <header class="album-book-header">

        <div>

          <span>
            CARD ARCHIVE
          </span>


          <strong>
            {{
              selectedElement ===
                "All"

                ? "ALL COLLECTION"

                : `${selectedElement.toUpperCase()} COLLECTION`
            }}
          </strong>

        </div>


        <div>

          {{
            filteredCards.length
          }}

          CARD{{
            filteredCards.length ===
              1
              ? ""
              : "S"
          }}

        </div>

      </header>


      <!-- GRID -->

      <div class="album-slots">

        <!-- CARD -->

        <article
          v-for="card in filteredCards"
          :key="card.id"
          class="album-slot collected"
          @click="
            openCard(
              card
            )
          "
        >

          <div
            class="album-card"
            :class="
              normalizeElement(
                card.element
              )
            "
          >

            <!-- HEADER -->

            <header>

              <div>

                <strong>
                  {{ card.name }}
                </strong>


                <small>
                  CARD
                </small>

              </div>


              <div class="card-hp">

                HP

                <strong>
                  {{ card.hp }}
                </strong>

              </div>

            </header>


            <!-- ELEMENT -->

            <div class="card-element">

              <span>

                {{
                  elementIcon(
                    card.element
                  )
                }}

              </span>


              {{
                elementLabel(
                  card.element
                )
              }}

            </div>


            <!-- IMAGE -->

            <div class="card-art">

              <img
                v-if="
                  isImageUrl(
                    card.image_url
                  )
                "
                :src="
                  card.image_url
                "
                :alt="
                  card.name
                "
              />


              <div
                v-else
                class="card-emoji"
              >

                {{
                  card.image_url ||
                  elementIcon(
                    card.element
                  )
                }}

              </div>

            </div>


            <!-- STATS -->

            <div class="card-stats">

              <div>

                <span>
                  ATK
                </span>

                <strong>
                  {{ card.attack }}
                </strong>

              </div>


              <div>

                <span>
                  DEF
                </span>

                <strong>
                  {{ card.defense }}
                </strong>

              </div>

            </div>


            <!-- UID -->

            <footer>

              <span>
                RFID
              </span>


              <code>
                {{
                  card.uid ||
                  "NO UID"
                }}
              </code>

            </footer>

          </div>


          <span class="slot-number">

            #{{ String(
              filteredCards.indexOf(card) + 1
            ).padStart(
              3,
              "0"
            ) }}

          </span>

        </article>


        <!-- EMPTY -->

        <article
          v-for="slot in emptySlots"
          :key="
            `empty-${slot}`
          "
          class="album-slot empty"
        >

          <div class="empty-card-slot">

            <div>
              ◉
            </div>


            <span>
              EMPTY SLOT
            </span>

          </div>

        </article>

      </div>

    </section>


    <!-- ===================================================
         EMPTY SEARCH
    ==================================================== -->

    <section
      v-if="
        !loading &&
        !errorMessage &&
        cards.length > 0 &&
        filteredCards.length === 0
      "
      class="empty-search"
    >

      <span>
        ◌
      </span>


      <strong>
        No cards found
      </strong>


      <p>
        Tidak ada kartu yang sesuai dengan filter.
      </p>

    </section>


    <!-- ===================================================
         CARD DETAIL MODAL
    ==================================================== -->

    <Transition name="modal">

      <div
        v-if="selectedCard"
        class="detail-overlay"
        @click.self="
          closeCard
        "
      >

        <section class="detail-modal">

          <button
            type="button"
            class="close-button"
            @click="
              closeCard
            "
          >
            ×
          </button>


          <!-- LARGE CARD -->

          <div
            class="detail-card"
            :class="
              normalizeElement(
                selectedCard.element
              )
            "
          >

            <header>

              <div>

                <small>
                  GAME CARD
                </small>


                <strong>
                  {{
                    selectedCard.name
                  }}
                </strong>

              </div>


              <div>

                HP

                <strong>
                  {{
                    selectedCard.hp
                  }}
                </strong>

              </div>

            </header>


            <div class="detail-art">

              <img
                v-if="
                  isImageUrl(
                    selectedCard.image_url
                  )
                "
                :src="
                  selectedCard.image_url
                "
                :alt="
                  selectedCard.name
                "
              />


              <span v-else>

                {{
                  selectedCard.image_url ||
                  elementIcon(
                    selectedCard.element
                  )
                }}

              </span>

            </div>


            <div class="detail-element">

              {{
                elementIcon(
                  selectedCard.element
                )
              }}

              {{
                elementLabel(
                  selectedCard.element
                )
              }}

            </div>

          </div>


          <!-- DETAILS -->

          <div class="detail-info">

            <span class="eyebrow">
              CARD INFORMATION
            </span>


            <h2>
              {{
                selectedCard.name
              }}
            </h2>


            <div class="detail-stats">

              <div>

                <span>
                  HP
                </span>

                <strong>
                  {{
                    selectedCard.hp
                  }}
                </strong>

              </div>


              <div>

                <span>
                  ATTACK
                </span>

                <strong>
                  {{
                    selectedCard.attack
                  }}
                </strong>

              </div>


              <div>

                <span>
                  DEFENSE
                </span>

                <strong>
                  {{
                    selectedCard.defense
                  }}
                </strong>

              </div>

            </div>


            <div class="detail-row">

              <span>
                ELEMENT
              </span>

              <strong>

                {{
                  elementIcon(
                    selectedCard.element
                  )
                }}

                {{
                  elementLabel(
                    selectedCard.element
                  )
                }}

              </strong>

            </div>


            <div class="detail-row">

              <span>
                RFID UID
              </span>

              <code>
                {{
                  selectedCard.uid
                }}
              </code>

            </div>


            <div class="detail-row">

              <span>
                CARD ID
              </span>

              <code>
                {{
                  selectedCard.id
                }}
              </code>

            </div>

          </div>

        </section>

      </div>

    </Transition>

  </main>
</template>


<style scoped>

/* =========================================================
   RESET
========================================================= */

* {
  box-sizing:
    border-box;
}


button,
input {
  font:
    inherit;
}


/* =========================================================
   PAGE
========================================================= */

.collection-page {
  min-height:
    100vh;

  position:
    relative;

  overflow-x:
    hidden;

  padding:
    32px;

  color:
    #e8f1ff;

  font-family:
    Inter,
    ui-sans-serif,
    system-ui,
    sans-serif;

  background:
    #08111f;
}


/* =========================================================
   BACKGROUND
========================================================= */

.album-background {
  position:
    fixed;

  inset:
    0;

  pointer-events:
    none;

  overflow:
    hidden;

  background:
    linear-gradient(
      180deg,
      #07101e,
      #0a1728
    );
}


.album-grid {
  position:
    absolute;

  inset:
    0;

  opacity:
    .17;

  background-image:
    linear-gradient(
      rgba(
        255,
        255,
        255,
        .05
      )
      1px,
      transparent
      1px
    ),
    linear-gradient(
      90deg,
      rgba(
        255,
        255,
        255,
        .05
      )
      1px,
      transparent
      1px
    );

  background-size:
    50px
    50px;
}


.album-glow {
  width:
    600px;

  height:
    600px;

  position:
    absolute;

  border-radius:
    50%;

  filter:
    blur(
      140px
    );

  opacity:
    .12;
}


.glow-one {
  top:
    -200px;

  left:
    -200px;

  background:
    #2daaff;
}


.glow-two {
  right:
    -200px;

  bottom:
    -250px;

  background:
    #6c4eff;
}


/* =========================================================
   HEADER
========================================================= */

.collection-header {
  width:
    min(
      100%,
      1450px
    );

  position:
    relative;

  z-index:
    2;

  display:
    flex;

  align-items:
    center;

  justify-content:
    space-between;

  gap:
    30px;

  margin:
    0 auto
    22px;

  padding:
    26px
    30px;

  border:
    1px solid
    rgba(
      125,
      170,
      210,
      .18
    );

  border-radius:
    24px;

  background:
    rgba(
      12,
      27,
      47,
      .88
    );

  box-shadow:
    0
    18px
    50px
    rgba(
      0,
      0,
      0,
      .26
    );

  backdrop-filter:
    blur(
      18px
    );
}


.eyebrow {
  color:
    #46c4ff;

  font-size:
    10px;

  font-weight:
    900;

  letter-spacing:
    2.2px;
}


.collection-header h1 {
  margin:
    4px 0;

  font-size:
    clamp(
      27px,
      4vw,
      42px
    );

  line-height:
    1;

  letter-spacing:
    -.8px;
}


.collection-header p {
  margin:
    10px 0 0;

  color:
    #8298af;

  font-size:
    13px;
}


.collection-counter {
  min-width:
    165px;

  padding:
    17px
    20px;

  text-align:
    center;

  border:
    1px solid
    rgba(
      73,
      193,
      255,
      .25
    );

  border-radius:
    18px;

  background:
    rgba(
      44,
      156,
      220,
      .08
    );
}


.collection-counter span,
.collection-counter small {
  display:
    block;

  color:
    #7ba2bc;

  font-size:
    8px;

  font-weight:
    800;

  letter-spacing:
    1px;
}


.collection-counter strong {
  display:
    block;

  margin:
    3px 0;

  color:
    white;

  font-size:
    32px;
}


/* =========================================================
   TOOLBAR
========================================================= */

.album-toolbar {
  width:
    min(
      100%,
      1450px
    );

  position:
    relative;

  z-index:
    2;

  display:
    flex;

  gap:
    12px;

  margin:
    0 auto
    14px;
}


.search-box {
  flex:
    1;

  display:
    flex;

  align-items:
    center;

  gap:
    12px;

  padding:
    0
    17px;

  border:
    1px solid
    #1e3550;

  border-radius:
    14px;

  background:
    rgba(
      14,
      29,
      49,
      .88
    );
}


.search-box span {
  color:
    #50c6ff;

  font-size:
    21px;
}


.search-box input {
  width:
    100%;

  padding:
    14px 0;

  border:
    0;

  outline:
    none;

  color:
    white;

  background:
    transparent;
}


.search-box input::placeholder {
  color:
    #607991;
}


.refresh-button {
  padding:
    0
    22px;

  border:
    1px solid
    rgba(
      72,
      189,
      255,
      .28
    );

  border-radius:
    14px;

  color:
    #dff6ff;

  background:
    rgba(
      48,
      158,
      224,
      .10
    );

  font-size:
    10px;

  font-weight:
    900;

  letter-spacing:
    1px;

  cursor:
    pointer;
}


/* =========================================================
   FILTER
========================================================= */

.element-filter {
  width:
    min(
      100%,
      1450px
    );

  position:
    relative;

  z-index:
    2;

  display:
    flex;

  gap:
    9px;

  margin:
    0 auto
    22px;

  overflow-x:
    auto;
}


.element-filter-button {
  min-width:
    104px;

  display:
    flex;

  align-items:
    center;

  justify-content:
    center;

  gap:
    7px;

  padding:
    10px
    12px;

  border:
    1px solid
    #1e354f;

  border-radius:
    12px;

  color:
    #7f97ad;

  background:
    rgba(
      12,
      28,
      47,
      .90
    );

  cursor:
    pointer;

  transition:
    .15s ease;
}


.element-filter-button strong {
  font-size:
    9px;

  letter-spacing:
    .8px;
}


.element-filter-button small {
  padding:
    2px
    6px;

  border-radius:
    10px;

  background:
    rgba(
      255,
      255,
      255,
      .06
    );

  font-size:
    8px;
}


.element-filter-button.active {
  border-color:
    #3bbcff;

  color:
    white;

  background:
    linear-gradient(
      135deg,
      rgba(
        31,
        134,
        205,
        .28
      ),
      rgba(
        59,
        188,
        255,
        .12
      )
    );
}


/* =========================================================
   ALBUM
========================================================= */

.album-book {
  width:
    min(
      100%,
      1450px
    );

  min-height:
    600px;

  position:
    relative;

  z-index:
    2;

  margin:
    0 auto;

  padding:
    26px
    28px
    35px
    60px;

  border:
    1px solid
    rgba(
      122,
      160,
      195,
      .18
    );

  border-radius:
    28px;

  background:
    linear-gradient(
      135deg,
      rgba(
        19,
        35,
        56,
        .98
      ),
      rgba(
        11,
        24,
        42,
        .98
      )
    );

  box-shadow:
    0
    30px
    80px
    rgba(
      0,
      0,
      0,
      .38
    );

  overflow:
    hidden;
}


/* =========================================================
   BINDER
========================================================= */

.binder-strip {
  width:
    34px;

  position:
    absolute;

  left:
    0;

  top:
    0;

  bottom:
    0;

  display:
    flex;

  flex-direction:
    column;

  align-items:
    center;

  justify-content:
    space-evenly;

  border-right:
    1px solid
    rgba(
      255,
      255,
      255,
      .07
    );

  background:
    rgba(
      0,
      0,
      0,
      .18
    );
}


.binder-strip span {
  width:
    18px;

  height:
    38px;

  border:
    3px solid
    #466078;

  border-right:
    0;

  border-radius:
    12px
    0
    0
    12px;
}


/* =========================================================
   BOOK HEADER
========================================================= */

.album-book-header {
  display:
    flex;

  align-items:
    flex-end;

  justify-content:
    space-between;

  margin-bottom:
    22px;

  padding-bottom:
    17px;

  border-bottom:
    1px solid
    rgba(
      255,
      255,
      255,
      .07
    );
}


.album-book-header span {
  display:
    block;

  margin-bottom:
    4px;

  color:
    #4fc7ff;

  font-size:
    8px;

  font-weight:
    900;

  letter-spacing:
    2px;
}


.album-book-header strong {
  font-size:
    17px;

  letter-spacing:
    .6px;
}


.album-book-header > div:last-child {
  color:
    #69849b;

  font-size:
    10px;

  font-weight:
    800;
}


/* =========================================================
   ALBUM SLOTS
========================================================= */

.album-slots {
  display:
    grid;

  grid-template-columns:
    repeat(
      4,
      minmax(
        0,
        1fr
      )
    );

  gap:
    22px;
}


.album-slot {
  min-width:
    0;

  position:
    relative;

  padding:
    12px;

  border:
    1px solid
    rgba(
      130,
      170,
      200,
      .14
    );

  border-radius:
    20px;

  background:
    rgba(
      255,
      255,
      255,
      .025
    );

  box-shadow:
    inset
    0
    0
    20px
    rgba(
      0,
      0,
      0,
      .20
    );
}


.album-slot.collected {
  cursor:
    pointer;
}


.album-slot.collected:hover
.album-card {
  transform:
    translateY(
      -6px
    )
    scale(
      1.015
    );
}


.slot-number {
  display:
    block;

  margin-top:
    8px;

  color:
    #536b81;

  text-align:
    center;

  font-size:
    8px;

  font-family:
    monospace;
}


/* =========================================================
   CARD
========================================================= */

.album-card {
  min-height:
    360px;

  display:
    flex;

  flex-direction:
    column;

  position:
    relative;

  padding:
    13px;

  border:
    2px solid
    rgba(
      255,
      255,
      255,
      .55
    );

  border-radius:
    17px;

  color:
    #152333;

  background:
    linear-gradient(
      135deg,
      #e8edf4,
      #c4d4e4
    );

  box-shadow:
    0
    15px
    30px
    rgba(
      0,
      0,
      0,
      .30
    );

  transition:
    transform
    .17s ease;
}


.album-card.fire {
  background:
    linear-gradient(
      135deg,
      #ffcec7,
      #ff7968
    );
}


.album-card.water {
  background:
    linear-gradient(
      135deg,
      #d0efff,
      #72b9f5
    );
}


.album-card.grass {
  background:
    linear-gradient(
      135deg,
      #d7f3d3,
      #79c77c
    );
}


.album-card.electric {
  background:
    linear-gradient(
      135deg,
      #fff6bc,
      #ffd83c
    );
}


.album-card.ice {
  background:
    linear-gradient(
      135deg,
      #dcfaff,
      #82dce8
    );
}


.album-card.dark {
  color:
    #f1f5f9;

  background:
    linear-gradient(
      135deg,
      #58606e,
      #202630
    );
}


.album-card > header {
  display:
    flex;

  justify-content:
    space-between;

  gap:
    10px;
}


.album-card > header strong {
  display:
    block;

  font-size:
    14px;

  font-weight:
    900;
}


.album-card > header small {
  opacity:
    .55;

  font-size:
    7px;

  font-weight:
    800;
}


.card-hp {
  font-size:
    8px;

  font-weight:
    900;
}


.card-hp strong {
  font-size:
    15px !important;
}


/* =========================================================
   ELEMENT
========================================================= */

.card-element {
  margin:
    7px 0;

  font-size:
    8px;

  font-weight:
    900;

  letter-spacing:
    .8px;
}


/* =========================================================
   ART
========================================================= */

.card-art {
  height:
    205px;

  overflow:
    hidden;

  display:
    grid;

  place-items:
    center;

  border:
    3px solid
    rgba(
      255,
      255,
      255,
      .72
    );

  border-radius:
    12px;

  background:
    rgba(
      15,
      28,
      43,
      .94
    );

  box-shadow:
    inset
    0
    0
    20px
    rgba(
      0,
      0,
      0,
      .38
    );
}


.card-art img {
  width:
    100%;

  height:
    100%;

  object-fit:
    cover;
}


.card-emoji {
  font-size:
    70px;
}


/* =========================================================
   STATS
========================================================= */

.card-stats {
  display:
    grid;

  grid-template-columns:
    1fr
    1fr;

  gap:
    8px;

  margin-top:
    10px;
}


.card-stats > div {
  display:
    flex;

  align-items:
    center;

  justify-content:
    space-between;

  padding:
    7px
    9px;

  border-radius:
    8px;

  background:
    rgba(
      255,
      255,
      255,
      .38
    );
}


.card-stats span {
  font-size:
    7px;

  font-weight:
    900;
}


.card-stats strong {
  font-size:
    15px;
}


.album-card > footer {
  margin-top:
    auto;

  padding-top:
    9px;

  display:
    flex;

  align-items:
    center;

  justify-content:
    space-between;

  gap:
    5px;

  font-size:
    7px;
}


.album-card > footer code {
  max-width:
    72%;

  overflow:
    hidden;

  text-overflow:
    ellipsis;

  white-space:
    nowrap;

  font-size:
    7px;
}


/* =========================================================
   EMPTY SLOT
========================================================= */

.empty-card-slot {
  min-height:
    360px;

  display:
    flex;

  align-items:
    center;

  justify-content:
    center;

  flex-direction:
    column;

  gap:
    13px;

  border:
    2px dashed
    rgba(
      108,
      147,
      177,
      .18
    );

  border-radius:
    17px;

  color:
    #405970;
}


.empty-card-slot div {
  width:
    65px;

  height:
    65px;

  display:
    grid;

  place-items:
    center;

  border:
    2px solid
    #405970;

  border-radius:
    50%;

  font-size:
    32px;
}


.empty-card-slot span {
  font-size:
    8px;

  font-weight:
    900;

  letter-spacing:
    1px;
}


/* =========================================================
   STATE
========================================================= */

.state-panel,
.empty-search {
  width:
    min(
      100%,
      1450px
    );

  position:
    relative;

  z-index:
    2;

  margin:
    0 auto;

  padding:
    70px
    30px;

  text-align:
    center;

  border:
    1px solid
    #1c3047;

  border-radius:
    24px;

  background:
    #0c1929;
}


.state-panel strong,
.empty-search strong {
  display:
    block;

  margin:
    14px 0
    5px;
}


.state-panel span,
.empty-search p {
  color:
    #678199;

  font-size:
    12px;
}


.loading-ring {
  width:
    42px;

  height:
    42px;

  margin:
    auto;

  border:
    4px solid
    #1d354e;

  border-top-color:
    #3bc3ff;

  border-radius:
    50%;

  animation:
    spin
    .7s linear
    infinite;
}


@keyframes spin {

  to {
    transform:
      rotate(
        360deg
      );
  }

}


/* =========================================================
   MODAL
========================================================= */

.detail-overlay {
  position:
    fixed;

  inset:
    0;

  z-index:
    100;

  display:
    grid;

  place-items:
    center;

  padding:
    20px;

  background:
    rgba(
      2,
      8,
      17,
      .78
    );

  backdrop-filter:
    blur(
      12px
    );
}


.detail-modal {
  width:
    min(
      900px,
      100%
    );

  position:
    relative;

  display:
    grid;

  grid-template-columns:
    330px
    1fr;

  gap:
    40px;

  padding:
    36px;

  border:
    1px solid
    #25435e;

  border-radius:
    28px;

  background:
    #0b1828;

  box-shadow:
    0
    40px
    100px
    rgba(
      0,
      0,
      0,
      .55
    );
}


.close-button {
  width:
    38px;

  height:
    38px;

  position:
    absolute;

  top:
    14px;

  right:
    14px;

  border:
    1px solid
    #29465f;

  border-radius:
    50%;

  color:
    white;

  background:
    #11263a;

  cursor:
    pointer;
}


.detail-card {
  min-height:
    450px;

  padding:
    17px;

  border:
    3px solid
    rgba(
      255,
      255,
      255,
      .62
    );

  border-radius:
    21px;

  color:
    #132333;

  background:
    #d8e2eb;
}


.detail-card.fire {
  background:
    linear-gradient(
      135deg,
      #ffd2ca,
      #ff7663
    );
}


.detail-card.water {
  background:
    linear-gradient(
      135deg,
      #d9f2ff,
      #67b7f5
    );
}


.detail-card.grass {
  background:
    linear-gradient(
      135deg,
      #ddf5da,
      #75c679
    );
}


.detail-card.electric {
  background:
    linear-gradient(
      135deg,
      #fff8ca,
      #ffdb42
    );
}


.detail-card.ice {
  background:
    linear-gradient(
      135deg,
      #e4fbff,
      #73d5e2
    );
}


.detail-card.dark {
  color:
    white;

  background:
    linear-gradient(
      135deg,
      #5d6675,
      #1d222a
    );
}


.detail-card > header {
  display:
    flex;

  justify-content:
    space-between;
}


.detail-card > header small {
  display:
    block;

  font-size:
    8px;
}


.detail-card > header strong {
  font-size:
    20px;
}


.detail-art {
  height:
    300px;

  display:
    grid;

  place-items:
    center;

  margin-top:
    14px;

  overflow:
    hidden;

  border:
    4px solid
    rgba(
      255,
      255,
      255,
      .65
    );

  border-radius:
    14px;

  background:
    #101d29;
}


.detail-art img {
  width:
    100%;

  height:
    100%;

  object-fit:
    cover;
}


.detail-art span {
  font-size:
    90px;
}


.detail-element {
  margin-top:
    15px;

  font-size:
    11px;

  font-weight:
    900;

  letter-spacing:
    1px;
}


.detail-info {
  align-self:
    center;
}


.detail-info h2 {
  margin:
    8px 0
    22px;

  font-size:
    35px;
}


.detail-stats {
  display:
    grid;

  grid-template-columns:
    repeat(
      3,
      1fr
    );

  gap:
    10px;

  margin-bottom:
    24px;
}


.detail-stats > div {
  padding:
    15px;

  border:
    1px solid
    #1e3a54;

  border-radius:
    14px;

  background:
    #102237;
}


.detail-stats span {
  display:
    block;

  color:
    #68849c;

  font-size:
    8px;

  font-weight:
    900;
}


.detail-stats strong {
  display:
    block;

  margin-top:
    3px;

  font-size:
    23px;
}


.detail-row {
  display:
    flex;

  justify-content:
    space-between;

  gap:
    15px;

  padding:
    13px 0;

  border-bottom:
    1px solid
    rgba(
      255,
      255,
      255,
      .07
    );
}


.detail-row span {
  color:
    #69849b;

  font-size:
    9px;

  font-weight:
    900;
}


.detail-row code {
  max-width:
    65%;

  color:
    #7ad3ff;

  overflow-wrap:
    anywhere;

  text-align:
    right;

  font-size:
    9px;
}


/* =========================================================
   MODAL TRANSITION
========================================================= */

.modal-enter-active,
.modal-leave-active {
  transition:
    opacity
    .18s ease;
}


.modal-enter-from,
.modal-leave-to {
  opacity:
    0;
}


/* =========================================================
   RESPONSIVE
========================================================= */

@media (
  max-width:
  1100px
) {

  .album-slots {
    grid-template-columns:
      repeat(
        3,
        1fr
      );
  }

}


@media (
  max-width:
  800px
) {

  .collection-page {
    padding:
      14px;
  }


  .collection-header {
    align-items:
      flex-start;

    flex-direction:
      column;
  }


  .collection-counter {
    width:
      100%;
  }


  .album-toolbar {
    flex-direction:
      column;
  }


  .refresh-button {
    min-height:
      46px;
  }


  .album-book {
    padding:
      20px
      14px
      24px
      46px;
  }


  .album-slots {
    grid-template-columns:
      repeat(
        2,
        1fr
      );

    gap:
      12px;
  }


  .album-card,
  .empty-card-slot {
    min-height:
      300px;
  }


  .card-art {
    height:
      155px;
  }


  .detail-modal {
    max-height:
      92vh;

    overflow-y:
      auto;

    grid-template-columns:
      1fr;

    padding:
      55px
      20px
      25px;
  }


  .detail-card {
    width:
      min(
        330px,
        100%
      );

    margin:
      auto;
  }

}


@media (
  max-width:
  500px
) {

  .album-slots {
    grid-template-columns:
      1fr
      1fr;
  }


  .album-slot {
    padding:
      6px;
  }


  .album-card {
    min-height:
      245px;

    padding:
      8px;

    border-radius:
      12px;
  }


  .card-art {
    height:
      120px;
  }


  .album-card > header strong {
    font-size:
      10px;
  }


  .card-stats strong {
    font-size:
      12px;
  }


  .empty-card-slot {
    min-height:
      245px;
  }

}

</style>