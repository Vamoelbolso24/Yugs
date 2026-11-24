-- Surf (Normal Spell)
-- Target 1 Level 5 or higher Aqua, Sea Serpent or Fish monster you control; apply 1 of these effects, also the
-- targeted monster cannot declare an attack this turn.
-- * Destroy all other FIRE monsters on the field, also destroy all other non-WATER monsters whose DEF is lower than
--   the targeted monster's ATK.
-- * Excavate the top 3 cards of your Deck, add any Aqua, Sea Serpent or Fish monsters among them to your hand, and
--   shuffle the rest into the Deck.
-- (You choose the effect when you activate it.)
local s,id=GetID()
local SEA=RACE_AQUA|RACE_SEASERPENT|RACE_FISH
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetCategory(CATEGORY_DESTROY+CATEGORY_TOHAND)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	e1:SetProperty(EFFECT_FLAG_CARD_TARGET)
	e1:SetTarget(s.target)
	e1:SetOperation(s.operation)
	c:RegisterEffect(e1)
end
function s.tgfilter(c) return c:IsFaceup() and c:IsLevelAbove(5) and c:IsRace(SEA) end
function s.desgroup(tp,tc)
	local atk=tc:GetAttack()
	return Duel.GetMatchingGroup(function(x)
		return x:IsFaceup() and (x:IsAttribute(ATTRIBUTE_FIRE)
			or (not x:IsAttribute(ATTRIBUTE_WATER) and not x:IsType(TYPE_LINK) and x:GetDefense()<atk))
	end,tp,LOCATION_MZONE,LOCATION_MZONE,tc)
end
function s.target(e,tp,eg,ep,ev,re,r,rp,chk,chkc)
	if chkc then return chkc:IsLocation(LOCATION_MZONE) and chkc:IsControler(tp) and s.tgfilter(chkc) end
	if chk==0 then return Duel.IsExistingTarget(s.tgfilter,tp,LOCATION_MZONE,0,1,nil) end
	Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_TARGET)
	local tc=Duel.SelectTarget(tp,s.tgfilter,tp,LOCATION_MZONE,0,1,1,nil):GetFirst()
	local canDig=Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>=3
	local op=Duel.SelectEffect(tp,{true,aux.Stringid(id,0)},{canDig,aux.Stringid(id,1)})
	e:SetLabel(op)
	if op==1 then
		local g=s.desgroup(tp,tc)
		Duel.SetOperationInfo(0,CATEGORY_DESTROY,g,#g,0,0)
	else
		Duel.SetOperationInfo(0,CATEGORY_TOHAND,nil,1,tp,LOCATION_DECK)
	end
end
function s.operation(e,tp)
	local tc=Duel.GetFirstTarget()
	if not (tc and tc:IsRelateToEffect(e) and tc:IsFaceup()) then return end
	if e:GetLabel()==1 then
		local g=s.desgroup(tp,tc)
		if #g>0 then Duel.Destroy(g,REASON_EFFECT) end
	elseif Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>=3 then
		Duel.ConfirmDecktop(tp,3)
		local g=Duel.GetDecktopGroup(tp,3):Filter(function(x) return x:IsMonster() and x:IsRace(SEA) and x:IsAbleToHand() end,nil)
		if #g>0 then
			Duel.DisableShuffleCheck()
			Duel.SendtoHand(g,nil,REASON_EFFECT)
			Duel.ConfirmCards(1-tp,g)
			Duel.ShuffleHand(tp)
		end
		Duel.ShuffleDeck(tp)
	end
	-- the targeted monster cannot attack this turn
	local e1=Effect.CreateEffect(e:GetHandler())
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
	e1:SetReset(RESETS_STANDARD_PHASE_END)
	tc:RegisterEffect(e1)
end
