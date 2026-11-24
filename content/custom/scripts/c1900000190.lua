-- Starmie
-- Evolution Summon from "Staryu" (hard once per turn).
-- (This card is also treated as a Spellcaster.)
-- If this card is Normal or Special Summoned: You can discard 1 card; destroy 1 face-up Spell your opponent controls.
-- If this card was Special Summoned by its own effect or by the effect of "Water Stone", you don't have to discard.
-- During each Standby Phase: You can excavate the top 3 cards of your Deck, and if there are any Pokemon monsters
-- among them, add 1 to your hand, also shuffle the rest into the Deck.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddEvolutionSummon(c,1900000189)   -- from Staryu
	Pokemon.AddExtraRace(c,RACE_SPELLCASTER)
	local e1=Effect.CreateEffect(c)
	e1:SetDescription(aux.Stringid(id,0))
	e1:SetCategory(CATEGORY_DESTROY)
	e1:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e1:SetProperty(EFFECT_FLAG_DELAY)
	e1:SetCode(EVENT_SUMMON_SUCCESS)
	e1:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local free=s.freeSwim(e:GetHandler())
		if chk==0 then return free or Duel.IsExistingMatchingCard(Card.IsDiscardable,tp,LOCATION_HAND,0,1,nil) end
		if not free then Duel.DiscardHand(tp,Card.IsDiscardable,1,1,REASON_COST|REASON_DISCARD) end
	end)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.spellfilter,tp,0,LOCATION_ONFIELD,1,nil) end
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,nil,1,1-tp,LOCATION_ONFIELD)
	end)
	e1:SetOperation(function(e,tp)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_DESTROY)
		local g=Duel.SelectMatchingCard(tp,s.spellfilter,tp,0,LOCATION_ONFIELD,1,1,nil)
		if #g>0 then Duel.HintSelection(g) Duel.Destroy(g,REASON_EFFECT) end
	end)
	c:RegisterEffect(e1)
	local e2=e1:Clone() e2:SetCode(EVENT_SPSUMMON_SUCCESS) c:RegisterEffect(e2)
	-- Each Standby Phase: excavate 3
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetCategory(CATEGORY_TOHAND)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_PHASE+PHASE_STANDBY)
	e3:SetRange(LOCATION_MZONE)
	e3:SetCountLimit(1)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>=3 end
	end)
	e3:SetOperation(function(e,tp)
		Pokemon.ExcavateAdd(tp,3,function(tc) return tc:IsSetCard(SET_POKEMON) and tc:IsMonster() end)
	end)
	c:RegisterEffect(e3)
end
s.listed_names={1900000189,CARD_WATER_STONE}
function s.spellfilter(c) return c:IsFaceup() and c:IsSpell() end
-- Summoned by its own Evolution Summon, or by Water Stone: no discard needed
function s.freeSwim(c)
	if Pokemon.IsEvolutionSummoned(c) then return true end
	local re=c:GetReasonEffect()
	return c:IsSummonType(SUMMON_TYPE_SPECIAL) and re and re:GetHandler():IsCode(CARD_WATER_STONE)
end
