-- Dragonite
-- You can Special Summon this card (from your hand) by Tributing 1 "Dragonair" you control.
-- If this card attacks a Defense Position monster, inflict piercing battle damage to your opponent.
-- If this card is attacked, it cannot declare an attack during the next turn.
-- If this card is destroyed and sent to the GY: You can banish 1 Dragon Pokemon monster from your hand or GY;
-- Special Summon this card in Defense Position.
local s,id=GetID()
s.listed_names={1900000224}
function s.initial_effect(c)
	local function mat(mc,tp) return mc:IsFaceup() and mc:IsCode(1900000224) and mc:IsReleasable() and Duel.GetMZoneCount(tp,mc)>0 end
	local e0=Effect.CreateEffect(c)
	e0:SetType(EFFECT_TYPE_FIELD)
	e0:SetCode(EFFECT_SPSUMMON_PROC)
	e0:SetProperty(EFFECT_FLAG_UNCOPYABLE)
	e0:SetRange(LOCATION_HAND)
	e0:SetValue(Pokemon.EVOLUTION)
	e0:SetCondition(function(e,c)
		if c==nil then return true end
		return Duel.IsExistingMatchingCard(mat,c:GetControler(),LOCATION_MZONE,0,1,nil,c:GetControler())
	end)
	e0:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,c)
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_RELEASE)
		local g=Duel.SelectMatchingCard(tp,mat,tp,LOCATION_MZONE,0,1,1,nil,tp)
		if #g==0 then return false end
		g:KeepAlive() e:SetLabelObject(g) return true
	end)
	e0:SetOperation(function(e,tp,eg,ep,ev,re,r,rp,c)
		local g=e:GetLabelObject() Duel.Release(g,REASON_COST) g:DeleteGroup()
	end)
	c:RegisterEffect(e0)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_SINGLE)
	e1:SetCode(EFFECT_PIERCE)
	c:RegisterEffect(e1)
	-- attacked -> no attack next turn
	local e2=Effect.CreateEffect(c)
	e2:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_CONTINUOUS)
	e2:SetCode(EVENT_BE_BATTLE_TARGET)
	e2:SetOperation(function(e)
		local c=e:GetHandler()
		c:ResetFlagEffect(id)
		c:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,2,Duel.GetTurnCount())
	end)
	c:RegisterEffect(e2)
	local e3=Effect.CreateEffect(c)
	e3:SetType(EFFECT_TYPE_SINGLE)
	e3:SetCode(EFFECT_CANNOT_ATTACK_ANNOUNCE)
	e3:SetCondition(function(e)
		local t=e:GetHandler():GetFlagEffectLabel(id)
		return t and Duel.GetTurnCount()==t+1
	end)
	c:RegisterEffect(e3)
	-- revive in Defense
	local e4=Effect.CreateEffect(c)
	e4:SetDescription(aux.Stringid(id,0))
	e4:SetCategory(CATEGORY_SPECIAL_SUMMON)
	e4:SetType(EFFECT_TYPE_SINGLE+EFFECT_TYPE_TRIGGER_O)
	e4:SetProperty(EFFECT_FLAG_DELAY)
	e4:SetCode(EVENT_TO_GRAVE)
	e4:SetCondition(function(e) return e:GetHandler():IsReason(REASON_DESTROY) end)
	e4:SetCost(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return Duel.IsExistingMatchingCard(s.cfilter,tp,LOCATION_HAND|LOCATION_GRAVE,0,1,e:GetHandler()) end
		Duel.Hint(HINT_SELECTMSG,tp,HINTMSG_REMOVE)
		local g=Duel.SelectMatchingCard(tp,s.cfilter,tp,LOCATION_HAND|LOCATION_GRAVE,0,1,1,e:GetHandler())
		Duel.Remove(g,POS_FACEUP,REASON_COST)
	end)
	e4:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local c=e:GetHandler()
		if chk==0 then return Duel.GetLocationCount(tp,LOCATION_MZONE)>0 and c:IsCanBeSpecialSummoned(e,0,tp,false,false,POS_FACEUP_DEFENSE) end
		Duel.SetOperationInfo(0,CATEGORY_SPECIAL_SUMMON,c,1,0,0)
	end)
	e4:SetOperation(function(e,tp)
		local c=e:GetHandler()
		if c:IsRelateToEffect(e) then Duel.SpecialSummon(c,0,tp,tp,false,false,POS_FACEUP_DEFENSE) end
	end)
	c:RegisterEffect(e4)
end
function s.cfilter(c) return c:IsSetCard(SET_POKEMON) and c:IsMonster() and c:IsRace(RACE_DRAGON) and c:IsAbleToRemoveAsCost() end
