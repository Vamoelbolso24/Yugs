// Game economy settings in one place. Change a number here and restart the server.
export const ECONOMY = {
  /** Coins for winning a duel (also when the opponent surrenders). */
  coinsPerWin: 2,
  /** Price of one pack in the shop. */
  packPrice: 10,
  /** Duels you must play (without surrendering) between pack purchases. */
  duelsPerPack: 10,
  /** Packs you can buy before the pack lock starts. */
  packsBeforeLock: 2,
  /** The lock after buying those packs: it ends at 00:00 UTC this many days after the day you bought the last one
   *  (bought on Monday at any time -> you can buy again from Thursday 00:00 UTC). */
  packLockDays: 3,
  /** Free packs a new player gets after choosing a starter deck (they don't count toward the lock). */
  freeStarterPacks: 5,
  /** ELO: how much one duel can move a rating (bigger = faster changes). Everyone starts at 1000. */
  eloK: 32,
  /** Max copies of one card in a collection. */
  maxCopies: 3,
} as const;
