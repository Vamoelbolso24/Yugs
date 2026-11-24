-- Barrage (Equip Spell)
-- Equip only to an "Exegg" monster you control. The equipped monster can attack all monsters your opponent
-- controls, once each.
-- At the end of the Battle Phase, if the equipped monster destroyed a monster by battle this turn: You can excavate
-- the top 4 cards of your Deck, and if there are any Spells that state "Pokemon" in their text, add 1 of them to
-- your hand, also shuffle the rest back into your Deck.
local s,id=GetID()
function s.initial_effect(c)
	aux.AddEquipProcedure(c,0,aux.FilterBoolFunction(Card.IsSetCard,SET_EXEGG))
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_ATTACK_ALL)
	e1:SetValue(1)
	c:RegisterEffect(e1)
	-- Remember that the equipped monster destroyed something by battle this turn
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_BATTLE_DESTROYING)
	e2:SetRange(LOCATION_SZONE)
	e2:SetOperation(function(e,tp,eg)
		local c=e:GetHandler()
		if c:GetEquipTarget() and eg:IsContains(c:GetEquipTarget()) then
			c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1)
		end
	end)
	c:RegisterEffect(e2)
	-- End of the Battle Phase: excavate 4
	local e3=Effect.CreateEffect(c)
	e3:SetDescription(aux.Stringid(id,0))
	e3:SetCategory(CATEGORY_TOHAND)
	e3:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e3:SetCode(EVENT_PHASE+PHASE_BATTLE)
	e3:SetRange(LOCATION_SZONE)
	e3:SetCountLimit(1)
	e3:SetCondition(function(e) return e:GetHandler():GetFlagEffect(id)>0 end)
	e3:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)>=4 end
	end)
	e3:SetOperation(function(e,tp)
		if Duel.GetFieldGroupCount(tp,LOCATION_DECK,0)<4 then return end
		Duel.ConfirmDecktop(tp,4)
		local g=Duel.GetDecktopGroup(tp,4):Filter(function(tc) return tc:IsSpell() and Pokemon.MentionsPokemon(tc) and tc:IsAbleToHand() end,nil)
		if #g>0 then
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_ATOHAND)
			local sg=g:Select(tp,1,1,nil)
			Duel.DisableShuffleCheck()
			Duel.SendtoHand(sg,nil,REASON_EFFECT)
			Duel.ConfirmCards(1-tp,sg)
		end
		Duel.ShuffleDeck(tp)
	end)
	c:RegisterEffect(e3)
end
s.listed_series={SET_EXEGG}
