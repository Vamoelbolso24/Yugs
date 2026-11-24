-- Power Plant (Field Spell)
-- If a Machine or Thunder Pokemon monster is destroyed by battle and sent to the GY: Its controller can excavate
-- the top 3 cards of their Deck, and if there is a Machine or Thunder Pokemon monster among them, they can add 1
-- of them to their hand, also shuffle the rest into the Deck.
-- If a player adds a card to their hand this way, they can't use this effect again this turn.
-- PATTERN: the effect is used by whoever controlled the destroyed monster (either player), so it's a
-- continuous effect that asks that player, with a per-player flag for "once per turn if they added a card".
local s,id=GetID()
local RACES=RACE_MACHINE|RACE_THUNDER
function s.initial_effect(c)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_ACTIVATE)
	e1:SetCode(EVENT_FREE_CHAIN)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_BATTLE_DESTROYED)
	e2:SetRange(LOCATION_FZONE)
	e2:SetOperation(s.op)
	c:RegisterEffect(e2)
end
function s.poke(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsRace(RACES) end
function s.op(e,tp,eg)
	for p=0,1 do
		local hit=eg:IsExists(function(tc) return tc:IsPreviousControler(p) and tc:IsLocation(LOCATION_GRAVE) and s.poke(tc) end,1,nil)
		if hit and Duel.GetFlagEffect(p,id)==0 and Duel.GetFieldGroupCount(p,LOCATION_DECK,0)>=3
			and Duel.SelectYesNo(p,aux.Stringid(id,0)) then
			Duel.Hint(HINT_CARD,0,id)
			Duel.ConfirmDecktop(p,3)
			local g=Duel.GetDecktopGroup(p,3):Filter(function(tc) return s.poke(tc) and tc:IsAbleToHand() end,nil)
			if #g>0 and Duel.SelectYesNo(p,aux.Stringid(id,1)) then
				Duel.Hint(HINT_SELECTMSG,p,HINTMSG_ATOHAND)
				local sg=g:Select(p,1,1,nil)
				Duel.DisableShuffleCheck()
				Duel.SendtoHand(sg,nil,REASON_EFFECT)
				Duel.ConfirmCards(1-p,sg)
				Duel.RegisterFlagEffect(p,id,RESET_PHASE|PHASE_END,0,1)
			end
			Duel.ShuffleDeck(p)
		end
	end
end
