-- Gym Leader - Koga (Continuous Spell)
-- You can only control 1 "Gym Leader" card.
-- The first time each DARK Pokemon monster you control would be destroyed by battle each turn, it is not.
-- Once while this card is face-up on the field, when a Spell/Trap card or effect your opponent activates
-- targets a DARK Pokemon monster you control: You can negate the activation, and if you do, destroy that card.
-- PATTERN: "once while this card is on the field" = SetCountLimit(1) + EFFECT_FLAG_NO_TURN_RESET.
local s,id=GetID()
function s.initial_effect(c)
	Pokemon.AddGymLeader(c)
	-- Battle protection, once per turn for each DARK Pokemon (a replacement that does nothing)
	local e1=Effect.CreateEffect(c)
	e1:SetType(EFFECT_TYPE_CONTINUOUS+EFFECT_TYPE_FIELD)
	e1:SetCode(EFFECT_DESTROY_REPLACE)
	e1:SetRange(LOCATION_SZONE)
	e1:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		local g=eg:Filter(s.protfilter,nil,tp)
		if chk==0 then return #g>0 end
		for tc in g:Iter() do tc:RegisterFlagEffect(id,RESET_EVENT|RESETS_STANDARD|RESET_PHASE|PHASE_END,0,1) end
		g:KeepAlive()
		if e:GetLabelObject() then e:GetLabelObject():DeleteGroup() end
		e:SetLabelObject(g)                      -- the ones saved this time
		return true
	end)
	e1:SetValue(function(e,tc) return e:GetLabelObject() and e:GetLabelObject():IsContains(tc) end)
	c:RegisterEffect(e1)
	-- Negate (once while face-up)
	local e2=Effect.CreateEffect(c)
	e2:SetDescription(aux.Stringid(id,0))
	e2:SetCategory(CATEGORY_NEGATE+CATEGORY_DESTROY)
	e2:SetType(EFFECT_TYPE_QUICK_O)
	e2:SetCode(EVENT_CHAINING)
	e2:SetRange(LOCATION_SZONE)
	e2:SetProperty(EFFECT_FLAG_NO_TURN_RESET+EFFECT_FLAG_DAMAGE_STEP+EFFECT_FLAG_DAMAGE_CAL)
	e2:SetCountLimit(1)
	e2:SetCondition(function(e,tp,eg,ep,ev,re,r,rp)
		return rp==1-tp and re:IsActiveType(TYPE_SPELL|TYPE_TRAP) and Duel.IsChainNegatable(ev)
			and Pokemon.TargetsMine(tp,ev,s.darkpoke)
	end)
	e2:SetTarget(function(e,tp,eg,ep,ev,re,r,rp,chk)
		if chk==0 then return true end
		Duel.SetOperationInfo(0,CATEGORY_NEGATE,eg,1,0,0)
		if re:GetHandler():IsDestructable() and re:GetHandler():IsRelateToEffect(re) then
			Duel.SetOperationInfo(0,CATEGORY_DESTROY,eg,1,0,0)
		end
	end)
	e2:SetOperation(function(e,tp,eg,ep,ev,re,r,rp)
		if Duel.NegateActivation(ev) and re:GetHandler():IsRelateToEffect(re) then
			Duel.Destroy(eg,REASON_EFFECT)
		end
	end)
	c:RegisterEffect(e2)
end
function s.darkpoke(c) return c:IsSetCard(SET_POKEMON) and c:IsAttribute(ATTRIBUTE_DARK) end
function s.protfilter(c,tp)
	return c:IsFaceup() and c:IsControler(tp) and c:IsLocation(LOCATION_MZONE) and s.darkpoke(c)
		and c:IsReason(REASON_BATTLE) and c:GetFlagEffect(id)==0
end
