-- Arcanine
-- Evolution Summon from "Growlithe" (hard once per turn).
-- If this card is Special Summoned this way, or by the effect of "Fire Stone": You can add 1 Ritual Spell
-- from your Deck to your hand.
-- If this card battles, your opponent cannot activate Spell/Trap cards or effects until the end of the Damage Step.
-- PATTERN: "Summoned by the effect of X" = look at the card's reason effect: c:GetReasonEffect():GetHandler().
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000086)   -- from Growlithe

	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND+CATEGORY_SEARCH)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SPSUMMON_SUCCESS)
	e1:SetCondition(function(e)
		local c=e:GetHandler()
		local re=c:GetReasonEffect()
		return Pokemon.IsEvolutionSummoned(c) or (re and re:GetHandler():IsCode(CARD_FIRE_STONE))
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.thfilter,tp,LOCATION_DECK,0,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
		local g=Duel.SelectMatchingCard(tp,s.thfilter,tp,LOCATION_DECK,0,1,1,nil)
		if #g>0 then
			Duel.SendtoHand(g,nil,REASON_EFFECT)
			Duel.ConfirmCards(1-tp,g)
		end
	end)
	c:RegisterEffect(e1)
	-- While it battles: no Spell/Trap activations from the opponent
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD)
	e2:SetProperty(EFFECT_FLAG_PLAYER_TARGET)
	e2:SetCode(EFFECT_CANNOT_ACTIVATE)
	e2:SetRange(LOCATION_MZONE)
	e2:SetTargetRange(0,1)
	e2:SetValue(function(e,re) return re:IsActiveType(TYPE_SPELL|TYPE_TRAP) end)
	e2:SetCondition(function(e)
		local c=e:GetHandler()
		return Duel.GetAttacker()==c or Duel.GetAttackTarget()==c
	end)
	c:RegisterEffect(e2)
end
s.listed_names={1900000086,CARD_FIRE_STONE}
function s.thfilter(c) return c:IsRitualSpell() and c:IsAbleToHand() end
