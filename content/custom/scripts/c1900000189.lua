-- Staryu
-- If this card is Normal Summoned: You can excavate the top 3 cards of your Deck, and if there are any Level 4 or
-- lower Pokemon monsters among them, add 1 to your hand, also shuffle the rest into the Deck.
local s,id=GetID()
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_TOHAND)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>=3 end
	end)
	e1:SetOperation(function(e,tp)
		Pokemon.ExcavateAdd(tp,3,function(tc) return tc:IsSetCard(SET_POKEMON) and tc:IsMonster() and tc:IsLevelBelow(4) end)
	end)
	c:RegisterEffect(e1)
end
