-- Swords Dance (Equip Spell)
-- Equip only to a Pokemon monster.
-- Once per turn: You can place 1 Swords Dance Counter on this card (max. 4), also the equipped monster cannot
-- declare an attack this turn. The equipped monster gains 700 ATK for each Swords Dance Counter on this card.
-- PATTERN: a counter limit = c:SetCounterLimit(COUNTER, max).
local s,id=GetID()
function s.initial_effect(c)
	c:SetCounterLimit(COUNTER_SDANCE,4)
	aux.AddEquipProcedure(c,nil,aux.FilterBoolFunction(Card.IsSetCard,SET_POKEMON))   -- nil = either player's Pokemon
	-- +700 ATK per counter
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_EQUIP)
	e1:SetCode(EFFECT_UPDATE_ATTACK)
	e1:SetValue(function(e) return e:GetHandler():GetCounter(COUNTER_SDANCE)*700 end)
	c:RegisterEffect(e1)
	-- Place a counter
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_COUNTER)
	e2:SetType(EFFECT_TYPE_IGNITION)
	e2:SetRange(LOCATION_SZONE)
	e2:SetCountLimit(1)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return c:GetEquipTarget() and c:IsCanAddCounter(COUNTER_SDANCE,1) end
		Duel.SetOperationInfo(0,CATEGORY_COUNTER,c,1,COUNTER_SDANCE,1)
	end)
	e2:SetOperation(function(e)
		local c=e:GetHandler()
		if not c:IsRelateToEffect(e) then return end
		c:AddCounter(COUNTER_SDANCE,1)
		local tc=c:GetEquipTarget()
		if tc then
			local e3=Effect.CreateEffect(c)
			e3:SetType(EFFECT_TYPE_SINGLE)
			e3:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
			e3:SetReset(RESETS_STANDARD_PHASE_END)
			tc:RegisterEffect(e3)
		end
	end)
	c:RegisterEffect(e2)
end
s.counter_place_list={COUNTER_SDANCE}
