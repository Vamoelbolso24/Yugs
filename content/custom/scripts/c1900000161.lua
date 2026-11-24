-- Crabhammer (Equip Spell)
-- Equip only to a "Krabby" or "Kingler" you control. If the equipped monster battles a Defense Position monster,
-- inflict piercing battle damage to your opponent.
-- During your End Phase: You can change the battle position of the equipped monster.
local s,id=GetID()
local KRABBY,KINGLER=1900000157,1900000158
function s.initial_effect(c)
	aux.AddEquipProcedure(c,0,aux.FilterBoolFunction(Card.IsCode,KRABBY,KINGLER))
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_PIERCE)
	c:RegisterEffect(e1)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_POSITION)
	e2:SetType(EFFECT_TYPE_FIELD+EFFECT_TYPE_TRIGGER_O)
	e2:SetCode(EVENT_PHASE+PHASE_END)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp) return Duel.IsTurnPlayer(tp) and e:GetHandler():GetEquipTarget() end)
	e2:SetOperation(function(e)
		local tc=e:GetHandler():GetEquipTarget()
		if e:GetHandler():IsRelateToEffect(e) and tc then
			Duel.ChangePosition(tc,POS_FACEUP_DEFENSE,POS_FACEUP_DEFENSE,POS_FACEUP_ATTACK,POS_FACEUP_ATTACK)
		end
	end)
	c:RegisterEffect(e2)
end
s.listed_names={KRABBY,KINGLER}
