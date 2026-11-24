-- Psyduck
-- Negate the effects of all "Weather Condition" cards, also those cards' names become "No Weather Condition".
-- Once per turn, when your opponent activates a card or effect that would destroy a monster(s) they control:
-- You can negate the activation, and if you do, destroy that card.
-- (The renamed cards are still "Weather Condition" cards, so they stay negated, and cards that check for
-- "Sandstorm", "Sunny Day" or "Rain Dance" by name no longer find them.)
-- Both effects are shared with Golduck: see custom_utility.lua.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddCloudNine(c)
	Pokemon.AddDestroyNegate(c,0)    -- Prompt 1
end
s.listed_series={SET_WEATHER}
