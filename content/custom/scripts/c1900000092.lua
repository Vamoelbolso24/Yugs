-- Gym Leader - Sabrina (Continuous Spell)
-- You can only control 1 "Gym Leader" card.
-- When this card is activated: You can add 1 Level 4 or lower Spellcaster or Fiend Pokemon monster from your
-- Deck to your hand.
-- If a Spellcaster or Fiend Pokemon monster you control would be destroyed by battle or card effect, you can
-- send this card to the GY instead.
-- If you control a Spellcaster or Fiend Pokemon monster: You can declare 1 card name; look at your opponent's
-- hand, and if that card is there, banish it, also your opponent banishes all other cards with that name from
-- their hand, Deck, and GY. You can only activate this effect of "Gym Leader - Sabrina" once per Duel.
-- PATTERN: declaring a card name = Duel.AnnounceCard(tp). "once per Duel" = EFFECT_COUNT_CODE_DUEL.
local s,id=GetID()
local RACES=RACE_SPELLCASTER|RACE_FIEND
function s.initial_effect(c)
	Pokemon.AddGymLeader(c,nil,nil,function(e,tp)
		Pokemon.ActivationSearch(e,tp,function(tc) return s.psychic(tc) and tc:IsLevelBelow(4) end,aux.Stringid(id,0))
	end)
	-- Destruction replacement
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
	e2:SetCode(EFFECT_DESTROY_REPLACE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetTarget(s.reptg)
	e2:SetValue(function(e,tc) return s.repfilter(tc,e:GetHandlerPlayer()) end)
	e2:SetOperation(function(e) Duel.SendtoGrave(e:GetHandler(),REASON_EFFECT|REASON_REPLACE) end)
	c:RegisterEffect(e2)
	-- Declare a card name (once per Duel)
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,1))
	e3:SetCategory(CATEGORY_REMOVE)
	e3:SetType(EFFECT_TYPE_IGNITION)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCountLimit(1,id,EFFECT_COUNT_CODE_DUEL)
	e3:SetCondition(function(e,tp) return Duel.IsExistingMatchingCard(s.psychicface,tp,LOCATION_MZONE,0,1,nil) end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,0,LOCATION_HAND)>0 end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_CODE)
		e:SetLabel(Duel.AnnounceCard(tp))       -- the declared card
	end)
	e3:SetOperation(s.declop)
	c:RegisterEffect(e3)
end
function s.psychic(c) return c:IsSetCard(SET_POKEMON) and c:IsRace(RACES) and c:IsMonster() end
function s.psychicface(c) return c:IsFaceup() and s.psychic(c) end
function s.repfilter(c,tp)
	return c:IsFaceup() and c:IsControler(tp) and c:IsLocation(LOCATION_MZONE) and s.psychic(c)
		and c:IsReason(REASON_BATTLE|REASON_EFFECT) and not c:IsReason(REASON_REPLACE)
end
function s.reptg(e,tp,eg,ep,ev,re,r,rp,chk)
	local c=e:GetHandler()
	if chk==0 then return eg:IsExists(s.repfilter,1,nil,tp) and c:IsAbleToGrave() and not c:IsStatus(STATUS_DESTROY_CONFIRMED) end
	return Duel.SelectEffectYesNo(tp,c,96)        -- 96 = "Use this card's effect instead?"
end
function s.declop(e,tp)
	local code=e:GetLabel()
	local hand=Duel.GetFieldGroup(tp,0,LOCATION_HAND)
	if #hand==0 then return end
	Duel.ConfirmCards(tp,hand)                    -- look at their whole hand
	Duel.ShuffleHand(1-tp)
	if not hand:IsExists(Card.IsCode,1,nil,code) then return end
	-- banish it from the hand, and every other copy from their hand, Deck and GY
	local g=Duel.GetMatchingGroup(Card.IsCode,tp,0,LOCATION_HAND|LOCATION_DECK|LOCATION_GRAVE,nil,code)
	Duel.Remove(g,POS_FACEUP,REASON_EFFECT)
	Duel.ShuffleDeck(1-tp)
end
