-- Seaking
-- Evolution Summon from "Goldeen" (hard once per turn).
-- If Summoned this way: You can add 1 "Waterfall" from your Deck to your hand, but you cannot activate cards, or
-- effects of cards, with that name for the rest of this turn.
-- If "Umi" is on the field, when this card attacks a Defense Position monster, inflict piercing battle damage.
-- While "Rain Dance" is on the field: You can Special Summon 1 Level 4 or lower Aqua, Sea Serpent or Fish monster
-- from your hand, also you cannot Special Summon monsters, except Aqua, Sea Serpent or Fish monsters, for the rest
-- of this turn. You can only activate this effect of "Seaking" once per turn.
local s,id=GetID()
local WATERFALL=1900000188
local RACES=RACE_AQUA|RACE_SEASERPENT|RACE_FISH
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000186)   -- from Goldeen
	-- Search Waterfall
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e) return Pokemon.IsEvolutionSummoned(e:GetHandler()) end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g==0 or Duel.SendtoHand(g,nil,REASON_EFFECT)==0 then return end
		Duel.ConfirmCards(1-tp,g)
		-- no Waterfall activations (card or effect) for the rest of this turn
		local e2=Effect.CreateEffect(e:GetHandler())
		e2:SetType(EFFECT_TYPE_FIELD)
		e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		e2:SetCode(EFFECT_CANNOT_ACTIVATE)
		e2:SetTargetRange(1,0)
		e2:SetValue(function(ef,re) return re:GetHandler():IsCode(WATERFALL) end)
		e2:SetReset(RESET_PHASE|PHASE_END)
		Duel.RegisterEffect(e2,tp)
	end)
	c:RegisterEffect(e1)
	-- Umi: piercing
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetCode(EFFECT_PIERCE)
	e3:SetCondition(function() return Pokemon.IsUmi() end)
	c:RegisterEffect(e3)
	-- Rain Dance: Special Summon from hand
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,1))
	e4:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e4:SetType(EFFECT_TYPE_IGNITION)
	e4:SetRange(LOCATION_MZONE)
	e4:SetCountLimit(1,id)
	e4:SetCondition(function() return Pokemon.IsOnField(CARD_RAIN_DANCE) end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0 and Duel.IsExistingMatchingCard(s.spfilter,tp,LOCATION_HAND,0,1,nil,e,tp) end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,nil,1,tp,LOCATION_HAND)
	end)
	e4:SetOperation(function(e,tp)
		if Duel.GetLocationCount(tp,LOCATION_MZONE)>0 then
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_SPSUMMON)
			local g=Duel.SelectMatchingCard(tp,s.spfilter,tp,LOCATION_HAND,0,1,1,nil,e,tp)
			if #g>0 then Duel.SpecialSummon(g,0,tp,tp,false,false,POS_FACEUP) end
		end
		-- "also": applies even if nothing was Summoned
		local e5=Effect.CreateEffect(e:GetHandler())
		e5:SetType(EFFECT_TYPE_FIELD)
		e5:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
		e5:SetCode(EFFECT_CANNOT_SPECIAL_SUMMON)
		e5:SetTargetRange(1,0)
		e5:SetTarget(function(ef,tc) return not tc:IsRace(RACES) end)
		e5:SetReset(RESET_PHASE|PHASE_END)
		Duel.RegisterEffect(e5,tp)
	end)
	c:RegisterEffect(e4)
end
s.listed_names={1900000186,WATERFALL,CARD_UMI,CARD_RAIN_DANCE}
function s.thfilter(c) return c:IsCode(WATERFALL) and c:IsAbleToHand() end
function s.spfilter(c,e,tp) return c:IsMonster() and c:IsLevelBelow(4) and c:IsRace(RACES) and c:IsCanBeSpecialSummoned(e,0,tp,false,false) end
