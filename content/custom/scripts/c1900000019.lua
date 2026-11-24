-- Kakuna
-- Evolution Summon from "Weedle" (hard once per turn).
-- The first time this card would be destroyed by battle, it is not.
-- During your Standby Phase: You can place a Harden Counter on this card (+300 DEF each).
-- During your Standby Phase: You can Tribute this card with 3 or more Harden Counters;
-- Special Summon 1 "Beedrill" from your hand, GY or Deck.
-- Same card as Metapod (c1900000016.lua) with different numbers.
local s,id=GetID()
local EVOLVES_FROM=1900000018   -- Weedle
local EVOLVES_TO=1900000020     -- Beedrill
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,EVOLVES_FROM)
	Pokemon.AddHarden(c,0)              -- Harden Counter + DEF boost (custom_utility.lua), uses Prompt 1

	-- "The first time this card would be destroyed by battle, it is not."
	-- PATTERN: EFFECT_INDESTRUCTABLE_COUNT. The value function says yes only for battle, and only
	-- once while this card is on the field (a flag remembers it was used; the flag is cleared if it leaves).
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetProperty(EFFECT_FLAG_SINGLE_RANGE)
	e1:SetRange(LOCATION_MZONE)
	e1:SetCode(EFFECT_INDESTRUCTABLE_COUNT)
	e1:SetCountLimit(1)
	e1:SetValue(s.indval)
	c:RegisterEffect(e1)

	-- Evolve with 3+ Harden Counters
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,1))      -- Prompt 2
	e2:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e2:SetRange(LOCATION_MZONE)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) and e:GetHandler():GetCounter(COUNTER_HARDEN)>=3 end)
	e2:SetCost(s.cost)
	e2:SetTarget(s.target)
	e2:SetOperation(s.operation)
	c:RegisterEffect(e2)
end
s.listed_names={EVOLVES_FROM,EVOLVES_TO}

function s.indval(e,re,r,rp)
	if (r&REASON_BATTLE)==0 then return false end
	local c=e:GetHandler()
	if c:GetFlagEffect(id)>0 then return false end
	c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD,0,1)
	return true
end
function s.cost(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then return c:IsReleasable() end
	Duel.Release(c,REASON_COST)
end
function s.filter(c,e,tp)
	return c:IsCode(EVOLVES_TO) and c:IsCanBeSpecialSummoned(e,0,tp,false,false)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk)
	if chk==0 then return Duel.GetMZoneCount(tp,e:GetHandler())>0
		and Duel.IsExistingMatchingCard(s.filter,tp,LOCATION_HAND|LOCATION_GRAVE|LOCATION_DECK,0,1,nil,e,tp) end
	Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND|LOCATION_GRAVE|LOCATION_DECK)
end
function s.operation(e,tp,eg,ep,ev,re,r,rp)
	if Duel.GetLocationCount(tp,LOCATION_MZONE)<=0 then return end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
	local g=Duel.SelectMatchingCard(tp,s.filter,tp,LOCATION_HAND|LOCATION_GRAVE|LOCATION_DECK,0,1,1,nil,e,tp)
	if #g>0 then Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP) end
end
