-- Weepingbell
-- Evolution Summon from "Bellsprout" (hard once per turn).
-- If Summoned this way: You can discard 1 card; excavate the top 4 cards of your Deck, and if there are any Plant
-- Pokemon monsters or "Sunny Day" among them, add 1 of them to your hand, also send the rest to the GY.
-- During your Standby Phase: You can make this card gain 200 ATK, or 400 ATK if "Sunny Day" is on the field.
-- This card cannot declare an attack the turn you activate this effect.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000112)   -- from Bellsprout
	Pokemon.AddGrowth(c,1)                      -- Prompt 2

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_TOGRAVE)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e) return Pokemon.IsEvolutionSummoned(e:GetHandler()) end)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
		Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD)
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>=4 end
	end)
	e1:SetOperation(function(e,tp)
		if Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)<4 then return end
		Duel.ConfirmDecktop(tp,4)                 -- excavate: both players see them
		local g=Duel.GetDecktopGroup(tp,4)
		local ok=g:Filter(s.thfilter,nil)
		Duel.DisableShuffleCheck()
		if #ok>0 then
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
			local sg=ok:Select(tp,1,1,nil)
			Duel.SendtoHand(sg,nil,REASON_EFFECT)
			Duel.ConfirmCards(1-tp,sg)
			g:Sub(sg)
		end
		Duel.SendtoGrave(g,REASON_EFFECT|REASON_EXCAVATE)   -- the rest go to the GY
	end)
	c:RegisterEffect(e1)
end
s.listed_names={1900000112,CARD_SUNNY_DAY}
function s.thfilter(c)
	return (c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsRace(RACE_PLANT)) or c:IsCode(CARD_SUNNY_DAY)
end
