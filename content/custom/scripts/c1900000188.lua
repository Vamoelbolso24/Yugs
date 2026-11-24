-- Waterfall (Equip Spell)
-- Equip only to an Aqua, Sea Serpent or Fish monster you control. The equipped monster gains 500 ATK.
-- If the equipped monster inflicts battle damage to your opponent by a direct attack: You can toss coins until you
-- get Tails, then apply the effect for the number of Heads you got:
-- * 1: Banish 1 card from your opponent's GY.
-- * 2 or more: Banish random cards from your opponent's hand, up to the number of Heads minus 1.
local s,id=GetID()
local RACES=RACE_AQUA|RACE_SEASERPENT|RACE_FISH
function s.initial_effect(c)
	aux.AddEquipProcedure(c,0,aux.FilterBoolFunction(Card.IsRace,RACES))
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(500)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_COIN+CATEGORY_REMOVE)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_BATTLE_DAMAGE)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCondition(function(e,tp,eg,ep)
		local tc=e:GetHandler():GetEquipTarget()
		return ep==1-tp and tc and Duel.GetAttacker()==tc and Duel.GetAttackTarget()==nil   -- a direct attack by it
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_COIN,nil,0,tp,1)
	end)
	e2:SetOperation(function(e,tp)
		local heads=0
		while Duel.TossCoin(tp,1)==COIN_HEADS do heads=heads+1 end   -- until Tails
		if heads==1 then
			Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
			local g=Duel.SelectMatchingCard(tp,Card.IsAbleToRemove,tp,0,LOCATION_GRAVE,1,1,nil)
			if #g>0 then Duel.Remove(g,POS_FACEUP,REASON_EFFECT) end
		elseif heads>=2 then
			local g=Duel.GetFieldGroup(tp,0,LOCATION_HAND)
			if #g>0 then Duel.Remove(g:RandomSelect(tp,math.min(heads-1,#g)),POS_FACEUP,REASON_EFFECT) end
		end
	end)
	c:RegisterEffect(e2)
end
s.toss_coin=true
