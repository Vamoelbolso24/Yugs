-- Slowpoke
-- Once per turn, during your Standby Phase: You can place 1 C-Counter on this card (max. 4). (Monsters with a
-- C-Counter gain 300 ATK/DEF for each C-Counter on them.) This card cannot declare an attack the turn you
-- activate this effect.
-- (Shared with Slowbro: Pokemon.AddCCounterStandby in custom_utility.lua.)
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddCCounterStandby(c,0)   -- Prompt 1
end
s.counter_place_list={COUNTER_C}
